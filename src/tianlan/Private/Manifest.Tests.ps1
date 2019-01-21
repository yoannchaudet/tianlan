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
        { (Get-Manifest a, b, c -ThrowOnMiss) } | Should -Throw 'Unable to locate a.b.c'
      }
    }

    Describe 'Add-ManifestProperty' {
      It 'Adds/replaces/removes new properties' {
        $manifest = @{}
        $object = Add-ManifestProperty -Manifest $manifest -Property 'test' -Value 'test'
        $object | Should -Be $manifest
        $object.test | Should -Be 'test'

        $object = Add-ManifestProperty -Manifest $manifest -Property 'test' -Value @(1, 2)
        $object | Should -Be $manifest
        $object.test | Should -Be @(1, 2)

        $object = Add-ManifestProperty -Manifest $manifest -Property 'test' -Value $null
        $object | Should -Be $manifest
        $object.psobject.properties | Should -Not -Contain 'test'
      }
    }

    Context 'Manifest definitions' {

      BeforeEach {
        $script:servicePrincipal = @{
          ServicePrincipal = @{
            Id            = 'object id'
            ApplicationId = 'application id'
          }
          Certificate      = @{
            Thumbprint = 'thumbprint'
          }
        }
        Mock 'Get-AzContext' {
          $ctx = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext
          $ctx.Tenant = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.PSAzureTenant
          $ctx.Tenant.Id = 'tenant id'
          return $ctx
        }
      }

      Describe 'Get-ServicePrincipalDefinition' {
        It 'Returns the proper definition' {
          $definition = Get-ServicePrincipalDefinition -ServicePrincipal $script:servicePrincipal -CertificateName 'cert name'
          $definition.id | Should -Be 'object id'
          $definition.applicationId | Should -Be 'application id'
          $definition.tenantId | Should -Be 'tenant id'
          $definition.certificate.thumbprint | Should -Be 'thumbprint'
          $definition.certificate.name | Should -Be 'cert name'
        }
      }

      Describe 'Get-EnvironmentDefinition' {
        It 'Returns the proper definition' {
          $spDefinition = Get-ServicePrincipalDefinition -ServicePrincipal $script:servicePrincipal -CertificateName 'cert name'
          $definition = Get-EnvironmentDefinition -Location 'location' -SubscriptionId 'subscription id' -AdminServicePrincipalDefinition $spDefinition
          $definition.location | Should -Be 'location'
          $definition.subscriptionId | Should -Be 'subscription id'
          $definition.servicePrincipals.admin.id | Should -Be 'object id'
          $definition.servicePrincipals.admin.certificate.name | Should -Be 'cert name'
        }
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