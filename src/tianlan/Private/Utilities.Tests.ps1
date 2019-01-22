InModuleScope Tianlan {
  Describe 'Invoke-Retry' {
    It 'Pass-throughs on success (with parameters)' {
      function Invoke-Me { param ([int] $I) }
      Mock 'Invoke-Me' { 42 }
      Invoke-Retry { param ([int] $I) Invoke-Me $I } -Parameters @{ I = 42 } | Should -Be 42
      Assert-MockCalled Invoke-Me -Times 1 -Exactly
    }

    It 'Pass-throughs on partial success' {
      function Invoke-Me2 { param ($i) }
      $script:calls = 0
      Mock 'Invoke-Me2' {
        $script:calls++
        if ($script:calls -lt 2) { throw 'x' } else { 'success' }
      }
      Invoke-Retry { Invoke-Me2 } | Should -Be 'success'
      Assert-MockCalled Invoke-Me2 -Times 2 -Exactly
    }

    It 'Does not retry more than X times' {
      function Invoke-Me3 {}
      Mock 'Invoke-Me3' { throw 'x' }
      { Invoke-Retry { Invoke-Me3 } -MaxRetries 6 -RetryDelay { 0 } } | Should -Throw 'x'
      Assert-MockCalled Invoke-Me3 -Times 7 -Exactly
    }

    It 'Waits when needed' {
      function Invoke-Me4 {}
      Mock 'Invoke-Me4' { throw 'x' }
      Mock 'Start-Sleep' { $Seconds | Should -Be 1 }
      { Invoke-Retry { Invoke-Me4 } -MaxRetries 2 -RetryDelay { param ($i) ($i - 1) } } | Should -Throw 'x'
      Assert-MockCalled Invoke-Me4 -Times 3 -Exactly
      Assert-MockCalled Start-Sleep -Times 1 -Exactly
    }
  }

  Describe 'Get-Hash' {
    It 'Hashes consistently' {
      $hash1 = Get-Hash 'hello'
      $hash2 = Get-Hash 'hello'
      $hash3 = Get-Hash 'Hello'
      $hash1 | Should -Be $hash2
      $hash3 | Should -Not -Be $hash1
    }

    It 'Returns fixed length hashes' {
      (Get-Hash 'x').length | Should -Be 10
      (Get-Hash 'x' -Length 1).length | Should -Be 1
      (Get-Hash 'x' -Length 20).length | Should -Be 20
      (Get-Hash 'x' -Length 40).length | Should -Be 40
      { Get-Hash 'x' -Length 0 } | Should -Throw
      { Get-Hash 'x' -Length 41 } | Should -Throw
    }
  }

  Describe 'Add-Property' {
    It 'Adds/replaces/removes properties to/from object' {
      $object = @{}
      $object | Add-Property 'test' -Value 1
      $object.test | Should -Be 1

      $object | Add-Property 'test' -Value 2
      $object.test | Should -Be 2

      $object | Add-Property 'test' -Value $null
      $object.psobject.properties | Should -Not -Contain 'test'
    }

    It 'Adds deep properties' {
      $object = @{
        a = "b"
        c = @{
          d = "e"
        }
      }

      $robject = ($object | Add-Property 'c', 'd' -Value 'new e')
      $robject.c.d | Should -Be 'new e'
      $object.c.d | Should -Be 'new e'

      $robject = ($object | Add-Property 'c2', 'd2', 'e2' -Value @(1, 2))
      $robject.c2.d2.e2 | Should -Be @(1, 2)
      $object.c2.d2.e2 | Should -Be @(1, 2)

      $robject = ($object | Add-Property 'c', 'd3', 'e3' -Value @{f3='test'})
      $robject.c.d3.e3.f3 | Should -Be 'test'
      $object.c.d3.e3.f3 | Should -Be 'test'
    }

    It 'Removes deep properties' {
      $object = @{
        a = "b"
        c = @{
          d = "e"
        }
      }
      $robject = ($object | Add-Property 'c', 'd' -Value $null)
      $robject.c | Should -Not -BeNullOrEmpty
      $object.c | Should -Not -BeNullOrEmpty
      $robject.psobject.properties | Should -Not -Contain 'd'
      $object.psobject.properties | Should -Not -Contain 'd'

      $object = @{
        a = @{
          b = @{
            c = 'c'
          }
        }
      }
      $robject = ($object | Add-Property 'a' -Value $null)
      $robject.psobject.properties | Should -Not -Contain 'a'
      $object.psobject.properties | Should -Not -Contain 'a'
    }

    It 'Serializes to JSON just fine' {
      $object = [pscustomobject] @{}
      $robject = $object | Add-Property 'a','b' -Value 1
      $robject.a.b | Should -Be 1
      $object.a.b | Should -Be 1
      $object -is [pscustomobject] | Should -BeTrue
      $robject -is [pscustomobject] | Should -BeTrue
      $json = $object | ConvertTo-Json
      $newObject = $json | ConvertFrom-Json
      Get-Property $newObject 'a', 'b' | Should -Be 1
    }
  }

  Describe 'Get-Property' {
    It 'Returns passed value if no filters are provided' {
      $x = @{}
      Get-Property $x | Should -Be $x
    }

    It 'Supports filtering' {
      $x = @{
        a    = @{
          b = 'c'
          d = @(1, 2)
        }
        c    = $false
        null = $null
      }
      (Get-Property $x a, b) | Should -Be 'c'
      (Get-Property $x a, d) | Should -Be @(1, 2)
      (Get-Property $x c) | Should -Be $false
      (Get-Property $x d) | Should -Be $null
      (Get-Property $x d -DefaultValue 42) | Should -Be 42
      (Get-Property $x null -DefaultValue 'not-null') | Should -Be 'not-null'
      { (Get-Property $x null -ThrowOnMiss) } | Should -Throw 'Unable to locate null'
      { (Get-Property $x a, b, c -ThrowOnMiss) } | Should -Throw 'Unable to locate a.b.c'
    }

    It 'Can return properties' {
      $x = @{}
      (Get-Property $x a, b) | Should -BeNullOrEmpty
      $x = @{ a = 1; b = 2; c =3 }
      (Get-Property $x -Properties) | Should -Be @('a', 'b', 'c')
      $x = @{ a = @{ a1 = $null }; b = 2; c =3 }
      (Get-Property $x 'a' -Properties) | Should -Be @('a1')
    }
  }

  Describe 'Get-JsonProperty' {
    It 'Returns passed value if no filters are provided' {
      $x = @{}
      Get-JsonProperty $x -Raw | Should -Be $x
      Get-JsonProperty $x | Should -Be '{}'
    }

    It 'Supports filtering' {
      $x = @{
        a    = @{
          b = 'c'
          d = @(1, 2)
        }
        c    = $false
        null = $null
      }
      (Get-JsonProperty $x a, b) | Should -Be '"c"'
      (Get-JsonProperty $x a, b -Raw) | Should -Be 'c'
      (Get-JsonProperty $x a, d) | Should -Match "[\\s*1,\\s*2\\s*]"
      (Get-JsonProperty $x a, d -Raw) | Should -Be @(1, 2)
      (Get-JsonProperty $x c) | Should -Be "false"
      (Get-JsonProperty $x c -Raw) | Should -Be $false
      (Get-JsonProperty $x d) | Should -Be $null
      (Get-JsonProperty $x d -Raw) | Should -Be $null
      (Get-JsonProperty $x d -DefaultValue 42) | Should -Be "42"
      (Get-JsonProperty $x d -DefaultValue 42 -Raw) | Should -Be 42
      (Get-JsonProperty $x null -DefaultValue 'not-null') | Should -Be '"not-null"'
      (Get-JsonProperty $x null -DefaultValue 'not-null' -Raw) | Should -Be 'not-null'
      { (Get-JsonProperty $x null -ThrowOnMiss) } | Should -Throw 'Unable to locate null'
      { (Get-JsonProperty $x null -ThrowOnMiss -Raw) } | Should -Throw 'Unable to locate null'
      { (Get-JsonProperty $x a, b, c -ThrowOnMiss) } | Should -Throw 'Unable to locate a.b.c'
      { (Get-JsonProperty $x a, b, c -ThrowOnMiss -Raw) } | Should -Throw 'Unable to locate a.b.c'
    }
  }

  Describe 'Use-TemporaryFile' {
    It 'Creates temporary file path and cleans after itself' {
      Use-TemporaryFile {
        param ($file)
        $file | Should -Not -BeNullOrEmpty
        $global:file = $file
        'hello' | Out-File -FilePath $file
        Test-Path -Path $global:file | Should -BeTrue
      }
      Test-Path -Path $global:file | Should -BeFalse
    }

    It 'Creates temporary file path and cleans after itself (even after exception)' {
      { Use-TemporaryFile {
          param ($file)
          $file | Should -Not -BeNullOrEmpty
          $global:file = $file
          'hello' | Out-File -FilePath $file
          Test-Path -Path $global:file | Should -BeTrue
          throw 'x'
        }} | Should -Throw
      Test-Path -Path $global:file | Should -BeFalse
    }

    It 'Creates temporary file path with requested extension' {
      Use-TemporaryFile {
        param ($file)
        $file.EndsWith('.pfx') | Should -BeTrue
      } -Extension '.pfx'
    }

    It 'Returns the output of the scriptblock' {
      Use-TemporaryFile {
        param ($file)
        "test"
      } -Extension '.pfx' | Should -Be "test"
    }

    It 'Passes arguments' {
      Use-TemporaryFile {
        param ($file, $test1, $test2, $test3)
        $test1 | Should -Be 'test1'
        $test2 | Should -Be 'test2'
        $test3 | Should -Be 'test3'
        "test"
      } -ScriptBlockArguments @('test1','test2','test3') -Extension '.pfx' | Should -Be "test"
    }
  }

  Describe 'Get-CertificateName' {
    It 'Returns valid certificate names' {
      Get-CertificateName 't' | Should -Be 'T-Certificate'
      Get-CertificateName 'test' | Should -Be 'Test-Certificate'
      Get-CertificateName 'Test' | Should -Be 'Test-Certificate'
      Get-CertificateName 'test123' | Should -Be 'Test-Certificate'
      Get-CertificateName 'test 1.2.3' | Should -Be 'Test-Certificate'
      Get-CertificateName 't e s t 1.2.3' | Should -Be 'Test-Certificate'
    }
  }
}