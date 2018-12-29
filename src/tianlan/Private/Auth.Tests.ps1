InModuleScope Tianlan {
  Describe 'Connect-Azure' {
    Context '1.a' {
      It 'Returns cached connection (user)' {
        # Set mocks
        Mock 'Get-AzContext' {
          @{
            Account      = @{ Type = 'User'; Id = 'some@email.com' }
            Subscription = @{ Id = 'test' }
          }
        }
        Mock 'Connect-AzAccount' {}

        # Connect
        Connect-Azure -SubscriptionId 'test' | Should -Be 'test'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 0
      }
    }

    Context '1.b' {
      It 'Returns cached connection (service principal)' {
        # Set mocks
        Mock 'Get-AzContext' {
          @{
            Account      = @{ Type = 'ServicePrincipal' }
            Subscription = @{ Id = 'test' }
          }
        }
        Mock 'Connect-AzAccount' {}

        # Set manifest
        Set-Manifest @"
        {
          "servicePrincipals": {
            "test.admin": {
              "certificateThumbprint": "thumbprint",
              "applicationId": "app id",
              "tenantId": "tenant id"
            }
          },
          "environments": {
            "test": {
              "subscriptionId": "test"
            }
          }
        }
"@

        # Connect
        Connect-Azure -Environment 'test' | Should -Be 'test'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 0
      }
    }

    Context '2.a' {
      It 'Invalidates cache (user)' {
        # Set mocks
        Mock 'Get-AzContext' {
          @{
            Account      = @{ Type = 'ServicePrincipal'; Id = 'some email that should not be here' }
            Subscription = @{ Id = 'test' }
          }
        }
        Mock 'Connect-AzAccount' {
          @{
            Account      = @{ Type = 'User' }
            Subscription = @{ Id = 'test' }
          }
        }

        # Connect
        Connect-Azure -SubscriptionId 'test' | Should -Be 'test'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 1
      }
    }

    Context '2.b' {
      It 'Invalidates cache (service principal)' {
        # Set mocks
        Mock 'Get-AzContext' {
          @{
            Account      = @{ Type = 'User' }
            Subscription = @{ Id = 'test' }
          }
        }
        Mock 'Connect-AzAccount' {
          @{
            Account      = @{ Type = 'ServicePrincipal' }
            Subscription = @{ Id = 'test' }
          }
        }
        Mock 'Set-AzContext' {}

        # Set manifest
        Set-Manifest @"
        {
          "servicePrincipals": {
            "test.admin": {
              "certificateThumbprint": "thumbprint",
              "applicationId": "app id",
              "tenantId": "tenant id"
            }
          },
          "environments": {
            "test": {
              "subscriptionId": "test"
            }
          }
        }
"@

        # Connect
        Connect-Azure -Environment 'test' | Should -Be 'test'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 1
        Assert-MockCalled 'Set-AzContext' -Times 1
      }
    }

    Context '3.a' {
      It 'Switches subscription without re-connecting (user)' {
        # Set mocks
        Mock 'Get-AzContext' {
          @{
            Account      = @{ Type = 'User'; Id = 'some@email.com' }
            Subscription = @{ Id = 'test1' }
          }
        }
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' { $true } -ParameterFilter { $SubscriptionId -eq 'test2' }
        Mock 'Set-AzContext' {
          @{
            Account      = @{ Type = 'User' }
            Subscription = @{ Id = 'test2' }
          }
        }

        # Connect
        Connect-Azure -SubscriptionId 'test2' | Should -Be 'test2'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 0
        Assert-MockCalled 'Get-AzSubscription' -Times 1
        Assert-MockCalled 'Set-AzContext' -Times 1
      }
    }

    Context '3.b' {
      It 'Switches subscription without re-connecting (service principal)' {
        # Set mocks
        Mock 'Get-AzContext' {
          @{
            Account      = @{ Type = 'ServicePrincipal' }
            Subscription = @{ Id = 'test1' }
          }
        }
        Mock 'Connect-AzAccount' {}
        Mock 'Get-AzSubscription' { $true } -ParameterFilter { $SubscriptionId -eq 'test2' }
        Mock 'Set-AzContext' {
          @{
            Account      = @{ Type = 'ServicePrincipal' }
            Subscription = @{ Id = 'test2' }
          }
        }

        # Set manifest
        Set-Manifest @"
        {
          "servicePrincipals": {
            "test.admin": {
              "certificateThumbprint": "thumbprint",
              "applicationId": "app id",
              "tenantId": "tenant id"
            }
          },
          "environments": {
            "test": {
              "subscriptionId": "test2"
            }
          }
        }
"@

        # Connect
        Connect-Azure -Environment 'test' | Should -Be 'test2'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 0
        Assert-MockCalled 'Get-AzSubscription' -Times 1
        Assert-MockCalled 'Set-AzContext' -Times 1
      }
    }

    Context '4.a' {
      It 'Throws if returned subscription does not match request (user)' {
        # Set mocks
        $script:getAzContextCounter = 0
        Mock 'Get-AzContext' {
          $script:getAzContextCounter++
          if ($script:getAzContextCounter -eq 1) {
            return $null
          }
          else {
            return @{ Subscription = @{ Id = 'something-else' } }
          }
        }
        Mock 'Connect-AzAccount' {
          @{
            Account      = @{
              Type = 'User'
            }
            Subscription = @{
              Id = 'something-else'
            }
          }
        }

        # Connect
        { Connect-Azure -SubscriptionId 'test' } | Should -Throw 'Unable to connect for requested subscription'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 1
      }
    }

    Context '4.b' {
      It 'Throws if returned subscription does not match request (service principal)' {
        # Set mocks
        $script:getAzContextCounter = 0
        Mock 'Get-AzContext' {
          $script:getAzContextCounter++
          if ($script:getAzContextCounter -eq 1) {
            return $null
          }
          else {
            return @{ Subscription = @{ Id = 'something-else' } }
          }
        }
        Mock 'Connect-AzAccount' {
          @{
            Account      = @{
              Type = 'ServicePrincipal'
            }
            Subscription = @{
              Id = 'something-else'
            }
          }
        }
        Mock 'Set-AzContext' {}

        # Set manifest
        Set-Manifest @"
      {
        "servicePrincipals": {
          "test.admin": {
            "certificateThumbprint": "thumbprint",
            "applicationId": "app id",
            "tenantId": "tenant id"
          }
        },
        "environments": {
          "test": {
            "subscriptionId": "expected-subscription"
          }
        }
      }
"@
        # Connect
        { Connect-Azure -Environment 'test' } | Should -Throw 'Unable to connect for requested subscription'

        # Assertions
        Assert-MockCalled 'Get-AzContext' -Times 1
        Assert-MockCalled 'Connect-AzAccount' -Times 1
        Assert-MockCalled 'Set-AzContext' -Times 1
      }
    }

    Context '5' {
      It 'Throws on invalid environment/service principal (service principal)' {
        # Set manifest
        Set-Manifest @"
        {
          "environments": {
            "test": {
              "subscriptionId": "expected-subscription"
            }
          }
        }
"@
        { Connect-Azure -Environment 'test2' } | Should -Throw 'Unable to locate environments.test2 in Manifest'
        { Connect-Azure -Environment 'test' } | Should -Throw 'Unable to locate servicePrincipals.test.admin in Manifest'
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