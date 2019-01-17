InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Describe 'Get-VaultName' {
      It 'Returns a hashed value' {
        Get-VaultName -Environment 'test' | Should -Be 'vaulta94a8fe5cc'
      }
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
        $ctx.Context.Name | Should -Be 'test'
        $ctx.Context.Hash | Should -Be 'a94a8fe5cc'
        $ctx.Context.VaultName | Should -Be 'vaulta94a8fe5cc'
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
        $script:ctx = Get-DeploymentContext -Environment 'test'
        $script:ctx.TemplateName = 'Test'
        New-Item -Path (Join-Path (Get-DeploymentPath) 'Templates') -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
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