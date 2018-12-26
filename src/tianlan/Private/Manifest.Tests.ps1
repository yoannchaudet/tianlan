InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      $global:DeploymentPath = 'testdrive:'
    }

    Describe 'Join-DeploymentPath' {
      BeforeEach {
        # Add some files there too
        'hello here' | Out-File -FilePath (Join-Path $global:DeploymentPath 'here.txt')
        New-Item -Path (Join-Path $global:DeploymentPath 'f') -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
        'hello there' | Out-File -FilePath (Join-Path $global:DeploymentPath 'f/there.txt')
      }

      It "Join paths with validation" {
        Join-DeploymentPath 'here.txt' | Should -Be (Join-Path $global:DeploymentPath 'here.txt')
        Join-DeploymentPath 'f/there.txt' | Should -Be (Join-Path $global:DeploymentPath 'f/there.txt')
        { Join-DeploymentPath 'there.txt' } | Should -Throw "Deployment path not found: $(Join-Path $global:DeploymentPath 'there.txt')"
      }

      It "Join paths without validation" {
        Join-DeploymentPath 'hello' -SkipValidation | Should -Be (Join-Path $global:DeploymentPath 'hello')
        Join-DeploymentPath 'hello/my/friend' -SkipValidation | Should -Be (Join-Path $global:DeploymentPath 'hello/my/friend')
      }
    }

    Describe 'Get-DefaultManifest' {
      It 'Returns a value' {
        Get-DefaultManifest | Should -Not -Be $null
        Get-DefaultManifest | Should -BeOfType PSCustomObject
      }
    }

    Describe 'Get-Manifest' {
      It 'Always returns a value' {
        Get-Manifest | Should -BeLike (Get-DefaultManifest)
      }

      It 'Returns actual provided Manifest.json file' {
        Set-Manifest '{
        "servicePrincipals": {
          "test": {}
        }
      }'
        (Get-Manifest).servicePrincipals.test | Should -Not -Be $null
      }

      It 'Supports properties lookup' {
        Set-Manifest '{
        "a": {
          "b": "c",
          "d": [1, 2]
        },
        "c": false
      }'
        (Get-Manifest servicePrincipals, test) | Should -Be $null
        (Get-Manifest a, b) | Should -Be 'c'
        (Get-Manifest a, d) | Should -Be @(1, 2)
        (Get-Manifest c) | Should -Be $false
        (Get-Manifest d) | Should -Be $null
        (Get-Manifest d -DefaultValue 42) | Should -Be 42
      }
    }

    Describe 'Set-Manifest' {
      It 'Accepts hashtables' {
        Set-Manifest @{
          hello = 'there'
          how   = @{
            are = @('you', 'sir', '!')
          }
        }
        (Get-Manifest hello) | Should -Be 'there'
        (Get-Manifest how, are) | Should -Be @('you', 'sir', '!')
      }

      It 'Accepts pscustomobjects' {
        Set-Manifest ([pscustomobject]@{
            hello = 'there'
            how   = @{
              are = @('you', 'sir', '!')
            }
          })
        (Get-Manifest hello) | Should -Be 'there'
        (Get-Manifest how, are) | Should -Be @('you', 'sir', '!')
      }

      It 'Accepts strings' {
        Set-Manifest '{
          "hello": "there",
          "how": {
            "are": ["you", "sir", "!"]
          }
        }'
        (Get-Manifest hello) | Should -Be 'there'
        (Get-Manifest how, are) | Should -Be @('you', 'sir', '!')
      }

      It 'Refuses anything else' {
        { Set-Manifest $false } | Should -Throw 'Unsupported content type'
        { Set-Manifest @(1, 2, 3) } | Should -Throw 'Unsupported content type'
        { Set-Manifest 1 } | Should -Throw 'Unsupported content type'
      }
    }
  }
}