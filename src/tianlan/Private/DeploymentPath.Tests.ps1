InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Describe 'Join-DeploymentPath' {
      BeforeEach {
        'hello here' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'here.txt')
        New-Item -Path (Join-Path (Get-DeploymentPath) 'f') -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
        'hello there' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'f/there.txt')
      }

      It 'Joins paths with validation' {
        Join-DeploymentPath 'here.txt' | Should -Be (Join-Path (Get-DeploymentPath) 'here.txt')
        Join-DeploymentPath 'f/there.txt' | Should -Be (Join-Path (Get-DeploymentPath) 'f/there.txt')
        { Join-DeploymentPath 'there.txt' } | Should -Throw "Deployment path not found: there.txt"
      }

      It 'Joins paths without validation' {
        Join-DeploymentPath 'hello' -SkipValidation | Should -Be (Join-Path (Get-DeploymentPath) 'hello')
        Join-DeploymentPath 'hello/my/friend' -SkipValidation | Should -Be (Join-Path (Get-DeploymentPath) 'hello/my/friend')
        Join-DeploymentPath 'README.md' -SkipValidation | Should -Be (Join-Path (Get-DeploymentPath) 'README.md')
      }

      It 'Looks in the user and default deployment paths (in that order)' {
        # README file exists in the default path
        Join-DeploymentPath 'README.md' | Should -Be (Join-Path $PSScriptRoot '../Deployment/README.md')
        # Without validation, only the user path is considered
        Join-DeploymentPath 'README.md' -SkipValidation | Should -Be (Join-Path (Get-DeploymentPath) 'README.md')
        # If we crate a README file in the user path, it should be returned (when validation is active)
        'read me' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'README.md')
        Join-DeploymentPath 'README.md' | Should -Be (Join-Path (Get-DeploymentPath) 'README.md')
      }
    }
  }
}
