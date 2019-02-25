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

  function Use-LocalCertificate {
    <#
    .SYNOPSIS
    Test helper: execute a script block in the context of a local certificate.
    #>

    param (
      [Parameter(Mandatory)]
      [scriptblock] $ScriptBlock
    )

    # Create a certificate
    $certificate = New-LocalCertificate -CommonName 'test'
    try {
      # Make sure the certificate was created
      $certificate | Should -Not -BeNull

      # Call the script block
      & $ScriptBlock
    }
    finally {
      # Remove the certificate
      Remove-LocalCertificate $certificate.Thumbprint | Should -BeTrue
    }
  }

  Describe 'New-LocalCertificate, Get-LocalCertificate, Remove-LocalCertificate' {
    It 'Generates/gets/removes certificates' {
      Use-LocalCertificate {
        # Get an invalid cert
        Get-LocalCertificate 'x' | Should -BeNull
        Remove-LocalCertificate 'x' | Should -BeFalse

        # Try to retrieve valid cert
        $certificate2 = Get-LocalCertificate -Thumbprint $certificate.Thumbprint
        $certificate2.Thumbprint | Should -Be $certificate.Thumbprint
        $certificate2.SubjectName.Name | Should -Be $certificate.SubjectName.Name
        $certificate2.HasPrivateKey | Should -Be $true
      }
    }
  }

  Describe 'Import-Certificate' {
    It 'Imports certificate only if not already in Key Vault' {
      Use-LocalCertificate {
        Mock 'Get-AzKeyVaultCertificate' {
          @{
            Certificate = @{
              Thumbprint = $certificate.Thumbprint
            }
          }
        }
        Mock 'Import-AzKeyVaultCertificate' {}
        Import-Certificate `
          -VaultName 'vault' `
          -Name 'name' `
          -Thumbprint $certificate.Thumbprint
        Assert-MockCalled 'Get-AzKeyVaultCertificate' -Times 1
        Assert-MockCalled 'Import-AzKeyVaultCertificate' -Times 0
      }
    }

    It 'Imports certificate if needed' {
      Use-LocalCertificate {
        Mock 'Get-AzKeyVaultCertificate' {}
        Mock 'Import-AzKeyVaultCertificate' `
          -ParameterFilter { $VaultName -eq 'vault' -and $Name -eq 'name' -and $CertificateCollection -eq $certificate } `
          -MockWith {}
        Import-Certificate `
          -VaultName 'vault' `
          -Name 'name' `
          -Thumbprint $certificate.Thumbprint
        Assert-MockCalled 'Get-AzKeyVaultCertificate' -Times 1
        Assert-MockCalled 'Import-AzKeyVaultCertificate' -Times 1
      }
    }
  }

  Describe 'Export-Certificate' {
    It 'Exports only if not already in certstore' {
      Use-LocalCertificate {
        Mock 'Get-AzKeyVaultSecret' {}
        Export-Certificate -VaultName 'vault' -Name 'name' -Thumbprint $certificate.Thumbprint
        Assert-MockCalled 'Get-AzKeyVaultSecret' -Times 0
      }
    }

    It 'Validates content type' {
      Use-LocalCertificate {
        Mock 'Get-AzKeyVaultSecret' {
          @{
            ContentType = 'invalid-content-type'
          }
        }
        { Export-Certificate -VaultName 'vault' -Name 'name' -Thumbprint 'some-thumbprint' } | Should -Throw 'Unexpected content type'
      }
    }

    It 'Exports certificate if needed' {
      Use-LocalCertificate {
        Mock 'Get-AzKeyVaultSecret' {
          @{
            ContentType = 'application/x-pkcs12'
            SecretValueText = [System.Convert]::ToBase64String($certificate.RawData)
          }
        }
        Remove-LocalCertificate $certificate.Thumbprint | Should -BeTrue
        Export-Certificate -VaultName 'vault' -Name 'name' -Thumbprint $certificate.Thumbprint
        Assert-MockCalled 'Get-AzKeyVaultSecret' -Times 1
        Get-LocalCertificate $certificate.Thumbprint | Should -Be $certificate
      }
    }
  }
}