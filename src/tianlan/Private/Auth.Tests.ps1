InModuleScope Tianlan {
  Describe 'Connect-Azure' {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Context '1.a' {
      It 'Connects when no context is available (interactive)' {
        Mock 'Get-AzContext' -ParameterFilter { $ListAvailable } { }
        Mock 'Get-AzContext' -ParameterFilter { !$ListAvailable } { 'selected context' }
        Mock 'Select-AzContext' {}
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' {}
        Mock 'Select-AzSubscription' {}

        Connect-Azure -SubscriptionId 'x' | Should -Be 'selected context'
        Assert-MockCalled 'Get-AzContext' -Times 2
        Assert-MockCalled 'Select-AzContext' -Times 0
        Assert-MockCalled 'Connect-AzAccount' -Times 1
        Assert-MockCalled 'Get-AzSubscription' -Times 0
        Assert-MockCalled 'Select-AzSubscription' -Times 0
      }
    }

    Context '1.b' {
      It 'Connects when no context is available (service principal)' {
        Mock 'Get-AzContext' -ParameterFilter { $ListAvailable } { }
        Mock 'Get-AzContext' -ParameterFilter { !$ListAvailable } { 'selected context' }
        Mock 'Select-AzContext' {}
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' { $true }
        Mock 'Select-AzSubscription' {}

        # Set manifest
        Set-Manifest @"
      {
        "environments": {
          "test": {
            "subscriptionId": "test",
            "servicePrincipals": {
              "admin": {
                "certificate": {
                  "thumbprint": "thumbprint"
                },
                "applicationId": "app id",
                "tenantId": "tenant id"
              }
            }
          }
        }
      }
"@

        Connect-Azure -Environment 'test' | Should -Be 'selected context'
        Assert-MockCalled 'Get-AzContext' -Times 2
        Assert-MockCalled 'Select-AzContext' -Times 0
        Assert-MockCalled 'Connect-AzAccount' -Times 1
        Assert-MockCalled 'Get-AzSubscription' -Times 1
        Assert-MockCalled 'Select-AzSubscription' -Times 1
      }
    }

    Context '1.c' {
      It 'Connects when no context is available (service principal - no access)' {
        Mock 'Get-AzContext' -ParameterFilter { $ListAvailable } { }
        Mock 'Get-AzContext' -ParameterFilter { !$ListAvailable } { 'selected context' }
        Mock 'Select-AzContext' {}
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' { $false }
        Mock 'Select-AzSubscription' {}

        # Set manifest
        Set-Manifest @"
      {
        "environments": {
          "test": {
            "subscriptionId": "test",
            "servicePrincipals": {
              "admin": {
                "certificate": {
                  "thumbprint": "thumbprint"
                },
                "applicationId": "app id",
                "tenantId": "tenant id"
              }
            }
          }
        }
      }
"@

        { Connect-Azure -Environment 'test' } | Should -Throw 'Service principal does not have access to requested subscription'
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Select-AzContext' -Times 0
        Assert-MockCalled 'Connect-AzAccount' -Times 1
        Assert-MockCalled 'Get-AzSubscription' -Times 1
        Assert-MockCalled 'Select-AzSubscription' -Times 0
      }
    }

    Context '2.a' {
      It 'Uses context when available (interactive)' {
        Mock 'Get-AzContext' -ParameterFilter { $ListAvailable } {
          $ctx = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext
          $ctx.Account = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.PSAzureRmAccount
          $ctx.Account.Type = 'User'
          $ctx.Subscription = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription
          $ctx.Subscription.Id = 'x'
          $ctx
        }
        Mock 'Get-AzContext' -ParameterFilter { !$ListAvailable } { 'selected context' }
        Mock 'Select-AzContext' { }
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' {}
        Mock 'Select-AzSubscription' {}

        Connect-Azure -SubscriptionId 'x' | Should -Be 'selected context'
        Assert-MockCalled 'Get-AzContext' -Times 2
        Assert-MockCalled 'Select-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 0
        Assert-MockCalled 'Get-AzSubscription' -Times 0
        Assert-MockCalled 'Select-AzSubscription' -Times 0
      }
    }

    Context '2.b' {
      It 'Uses context when available (service principal)' {
        Mock 'Get-AzContext' -ParameterFilter { $ListAvailable } {
          $ctx = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext
          $ctx.Account = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.PSAzureRmAccount
          $ctx.Account.Type = 'ServicePrincipal'
          $ctx.Account.Id = 'app id'
          $ctx.Subscription = New-MockObject -Type Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription
          $ctx.Subscription.Id = 'test'
          $ctx
        }
        Mock 'Get-AzContext' -ParameterFilter { !$ListAvailable } { 'selected context' }
        Mock 'Select-AzContext' { }
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' {}
        Mock 'Select-AzSubscription' {}

        # Set manifest
        Set-Manifest @"
      {
        "environments": {
          "test": {
            "subscriptionId": "test",
            "servicePrincipals": {
              "admin": {
                "certificate": {
                  "thumbprint": "thumbprint"
                },
                "applicationId": "app id",
                "tenantId": "tenant id"
              }
            }
          }
        }
      }
"@

        Connect-Azure -Environment 'test' | Should -Be 'selected context'
        Assert-MockCalled 'Get-AzContext' -Times 2
        Assert-MockCalled 'Select-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 0
        Assert-MockCalled 'Get-AzSubscription' -Times 0
        Assert-MockCalled 'Select-AzSubscription' -Times 0
      }
    }
  }

  Describe 'New-RandomPassword' {
    It 'Produces random passwords (same length)' {
      $p1 = New-RandomPassword
      $p2 = New-RandomPassword
      $p1.Length | Should -Be 16
      $p2.Length | Should -Be 16
      $p1 | Should -Not -Be $p2
    }

    It 'Produces passwords of arbirary lengths' {
      (New-RandomPassword -Length 5).Length | Should -Be 5
      (New-RandomPassword -Length 64).Length | Should -Be 64
    }

    It 'Returns a secure string if requested' {
      New-RandomPassword -AsSecureString | Should -BeOfType [securestring]
    }
  }

  Describe 'New-Certificate, Get-Certificate, Remove-Certificate' {
    It 'Generates/gets/removes certificates' {
      # Try to create a new cert
      $certificate = New-Certificate -CommonName 'test'
      try {
        $certificate | Should -Not -BeNull

        # Get an invalid cert
        Get-Certificate 'x' | Should -BeNull
        Remove-Certificate 'x' | Should -BeFalse

        # Try to retrieve valid cert
        $certificate2 = Get-Certificate -Thumbprint $certificate.Thumbprint
        $certificate2.Thumbprint | Should -Be $certificate.Thumbprint
        $certificate2.SubjectName.Name | Should -Be $certificate.SubjectName.Name
        $certificate2.HasPrivateKey | Should -Be $true
      }
      finally {
        # Try to remove the certificate
        Remove-Certificate $certificate.Thumbprint | Should -BeTrue
      }
    }
  }
}