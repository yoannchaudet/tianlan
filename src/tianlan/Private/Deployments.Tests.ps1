InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Describe 'Get-DeploymentContext' {
      It 'Returns environment context' {
        { Get-DeploymentContext -Environment 'test' } | Should -Throw
        Set-Manifest @"
        {
          "environments": {
            "test": {
              "subscriptionId": "subscription id",
              "location": "location"
            }
          }
        }
"@
        $ctx = Get-DeploymentContext -Environment 'test'
        $ctx.TemplateName | Should -Be '$Environment'
        $ctx.ResourceGroup | Should -Be 'test'
        $ctx.Location | Should -Be 'location'
        $ctx.ContextType | Should -Be 'Environment'
        $ctx.ContextName | Should -Be 'test'
      }
    }

    Describe 'Get-DeploymentFile' {
      BeforeEach {
        New-Item -Path (Join-Path (Get-DeploymentPath) 'Templates') -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/X.Template.json')
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/X.integration.Template.json')
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Y.integration.Template.json')
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Z.Template.json')
      }

      It 'Returns deployment file in priority order' {
        Get-DeploymentFile `
          -Context 'random' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.Template.json'))
        Get-DeploymentFile `
          -Context 'integration' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.integration.Template.json'))
        { Get-DeploymentFile `
            -Context 'random' `
            -Path 'Templates/Y' `
            -Extension 'Template.json' } | Should -Throw
        Get-DeploymentFile `
          -Context 'integration' `
          -Path 'Templates/Y' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/Y.integration.Template.json'))
        Get-DeploymentFile `
          -Context 'integration' `
          -Path 'Templates/Z' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/Z.Template.json'))
        { Get-DeploymentFile `
            -Context 'random' `
            -Path 'Templates/' `
            -Extension 'Template.json' } | Should -Throw
      }
    }

    Describe 'Get-TemplateParameters' {
      BeforeAll {
        Set-Manifest @"
        {
          "environments": {
            "test": {
              "subscriptionId": "subscription id",
              "location": "location"
            }
          }
        }
"@
        New-Item -Path (Join-Path (Get-DeploymentPath) 'Parameters') -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null
      }

      It 'Parses valid file' {
        @"
        {
          "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
          "contentVersion": "1.0.0.0",
          "parameters": {
            "a": {
              "value": 1
            },
            "b": {
              "value": "2"
            },
            "c": {
              "value": null
            },
            "d": {
              "value": [1, 2, false]
            },
            "e": {
              "value": {
                "a": 0
              }
            }
          }
        }
"@ | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Parameters/$Environment.Parameters.json')
        $parameters = Get-TemplateParameters -Context (Get-DeploymentContext -Environment 'test')
        $parameters.a | Should -Be 1
        $parameters.b | Should -Be "2"
        $parameters.c | Should -Be $null
        $parameters.d | Should -Be @(1, 2, $false)
        $parameters.e.a | Should -Be 0
      }

      It 'Parses valid file (and ignore invalid parameters)' {
        @"
        {
          "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
          "contentVersion": "1.0.0.0",
          "parameters": {
            "a": {
              "value": 1
            },
            "b": {
            }
          }
        }
"@ | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Parameters/$Environment.Parameters.json')
        $parameters = Get-TemplateParameters -Context (Get-DeploymentContext -Environment 'test')
        $parameters.a | Should -Be 1
        $parameters.Count | Should -Be 1
      }

      It 'Parses valid file (without parameters)' {
        @"
        {
          "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
          "contentVersion": "1.0.0.0",
          "parameters": {}
        }
"@ | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Parameters/$Environment.Parameters.json')
        $parameters = Get-TemplateParameters -Context (Get-DeploymentContext -Environment 'test')
        $parameters.Count | Should -Be 0
      }

      It 'Parses invalid valid file (without parameters property)' {
        @"
        {
          "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
          "contentVersion": "1.0.0.0"
        }
"@ | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Parameters/$Environment.Parameters.json')
        $parameters = Get-TemplateParameters -Context (Get-DeploymentContext -Environment 'test')
        $parameters.Count | Should -Be 0
      }

      It 'Fails to parse invalid JSON file' {
        @"
        {{}}
"@ | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Parameters/$Environment.Parameters.json')
        { Get-TemplateParameters -Context (Get-DeploymentContext -Environment 'test') } | Should -Throw
      }
    }
  }
}