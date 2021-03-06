InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Describe 'Get-VaultName' {
      It 'Returns a hashed value' {
        Get-VaultName -Environment 'test' | Should -Be 'vaulta94a8fe5cc'
        Get-VaultName -Environment 'test' -Stamp 'test' | Should -Be 'vault4d233e1542'
      }
    }

    Describe 'Get-EnvironmentContext' {
      It 'Returns environment context' {
        { Get-EnvironmentContext -Environment 'test' } | Should -Throw
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
        $ctx = Get-EnvironmentContext -Environment 'test'
        $ctx.TemplateName | Should -Be '$KeyVault'
        $ctx.ResourceGroup | Should -Be 'test'
        $ctx.Location | Should -Be 'location'
        $ctx.Context.Name | Should -Be 'test'
        $ctx.Context.Environment | Should -Be 'test'
        $ctx.Context.Stamp | Should -BeNullOrEmpty
        $ctx.Context.Hash | Should -Be 'a94a8fe5cc'
        $ctx.Context.VaultName | Should -Be 'vaulta94a8fe5cc'
      }
    }

    Describe 'Get-StampContext' {
      It 'Returns stamp context' {
        { Get-StampContext -Environment 'env' -Stamp 'du' } | Should -Throw
        Set-Manifest @"
        {
          "environments": {
            "env": {
              "subscriptionId": "subscription id",
              "location": "location",
              "stamps": {
                "du": {
                  "location": "du location"
                }
              }
            }
          }
        }
"@
        { Get-StampContext -Environment 'env' -Stamp 'bad du' } | Should -Throw
        $ctx = Get-StampContext -Environment 'env' -Stamp 'du'
        $ctx.TemplateName | Should -Be '$KeyVault'
        $ctx.ResourceGroup | Should -Be 'env_du'
        $ctx.Location | Should -Be 'du location'
        $ctx.Context.Name | Should -Be 'du'
        $ctx.Context.Environment | Should -Be 'env'
        $ctx.Context.Stamp | Should -Be 'du'
        $ctx.Context.Hash | Should -Be '8200331830'
        $ctx.Context.VaultName | Should -Be 'vault8200331830'
      }
    }

    Describe 'Get-DeploymentFile' {
      BeforeEach {
        New-Item -Path (Join-Path (Get-DeploymentPath) 'Templates') -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/X.Template.json')
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/X.env.Template.json')
        '{}' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/X.du.env.Template.json')
      }

      It 'Returns deployment file in priority order' {
        Get-DeploymentFile `
          -Environment 'random' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.Template.json'))
        Get-DeploymentFile `
          -Environment 'env' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.env.Template.json'))
        Get-DeploymentFile `
          -Environment 'env' `
          -Stamp 'du' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.du.env.Template.json'))
        Get-DeploymentFile `
          -Environment 'env' `
          -Stamp 'baddu' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.env.Template.json'))
        Get-DeploymentFile `
          -Environment 'badenv' `
          -Stamp 'du' `
          -Path 'Templates/X' `
          -Extension 'Template.json' | Should -Be ((Join-Path (Get-DeploymentPath) 'Templates/X.Template.json'))
        Get-DeploymentFile `
          -Environment 'random' `
          -Path 'Templates/notfound' `
          -Extension 'Template.json' | Should -BeNullOrEmpty
      }
    }

    Describe 'Get-TemplateParameter' {
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
        $script:ctx = Get-EnvironmentContext -Environment 'test'
        $script:ctx.TemplateName = 'Test'
        New-Item -Path (Join-Path (Get-DeploymentPath) 'Templates') -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
      }

      It 'Skips parameter file if none' {
        Get-TemplateParameter -Context $script:ctx | Should -BeNullOrEmpty
      }

      It 'Renders (empty) parameter file' {
        $file = @"
        {
        }
"@
        $file | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Test.Parameters.json')
        $json = Get-TemplateParameter -Context $script:ctx | ConvertFrom-Json
        @($json.psobject.properties).Count | Should -Be 0
      }

      It 'Renders (context) parameter file' {
        $file = @"
        {
          "a": `$(Get-Context 'Hash'),
          "b": `$(Get-Context 'Name'),
          "c": `$(Get-Context 'VaultName')
        }
"@
        $file | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Test.Parameters.json')
        $json = Get-TemplateParameter -Context $script:ctx | ConvertFrom-Json
        @($json.psobject.properties).Count | Should -Be 3
        $json.a | Should -Be $ctx.Context.Hash
        $json.b | Should -Be $ctx.Context.Name
        $json.c | Should -Be $ctx.Context.VaultName
      }

      It 'Fails on invalid (context) filters' {
        $file = @"
        {
          "a": `$(Get-Context 'InvalidFilter')
        }
"@
        $file | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Test.Parameters.json')
        { Get-TemplateParameter -Context $script:ctx } | Should -Throw
      }

      It 'Renders (context+manifest) parameter file' {
        $file = @"
        {
          "a": `$(Get-Context),
          "b": `$(Get-Manifest 'environments','test')
        }
"@
        $file | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Test.Parameters.json')
        $json = Get-TemplateParameter -Context $script:ctx | ConvertFrom-Json
        @($json.psobject.properties).Count | Should -Be 2
        $json.a.Hash | Should -Be $ctx.Context.Hash
        $json.a.Name | Should -Be $ctx.Context.Name
        $json.a.VaultName | Should -Be $ctx.Context.VaultName
        $json.b.subscriptionId | Should -Be 'subscription id'
        $json.b.location | Should -Be 'location'
      }

      It 'Fails on invalid (manifest) filters' {
        $file = @"
        {
          "a": `$(Get-Manifest 'environments','bad')
        }
"@
        $file | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'Templates/Test.Parameters.json')
        { Get-TemplateParameter -Context $script:ctx } | Should -Throw
      }
    }
  }
}