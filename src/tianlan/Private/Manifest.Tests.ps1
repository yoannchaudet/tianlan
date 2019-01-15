InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Describe 'Get-NewManifest' {
      It 'Returns a value' {
        Get-NewManifest | Should -Not -Be $null
        Get-NewManifest | Should -BeOfType PSCustomObject
      }
    }

    Describe 'Get-Manifest' {
      It 'Always returns a value' {
        Get-Manifest | Should -BeLike (Get-NewManifest)
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
        "c": false,
        "null": null
      }'
        (Get-Manifest servicePrincipals, test) | Should -Be $null
        (Get-Manifest a, b) | Should -Be 'c'
        (Get-Manifest a, d) | Should -Be @(1, 2)
        (Get-Manifest c) | Should -Be $false
        (Get-Manifest d) | Should -Be $null
        (Get-Manifest d -DefaultValue 42) | Should -Be 42
        (Get-Manifest null -DefaultValue 'not-null') | Should -Be 'not-null'
        { (Get-Manifest null -ThrowOnMiss) } | Should -Throw 'Unable to locate null'
        { (Get-Manifest a,b,c -ThrowOnMiss) } | Should -Throw 'Unable to locate a.b.c'
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