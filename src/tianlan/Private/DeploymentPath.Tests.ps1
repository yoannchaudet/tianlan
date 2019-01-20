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

      It 'Joins paths' {
        Join-DeploymentPath 'here.txt' | Should -Be (Join-Path (Get-DeploymentPath) 'here.txt')
        Join-DeploymentPath 'f/there.txt' | Should -Be (Join-Path (Get-DeploymentPath) 'f/there.txt')
        Join-DeploymentPath 'there.txt' | Should -BeNullOrEmpty
        { Join-DeploymentPath 'there.txt' -ThrowOnMiss } | Should -Throw "Deployment path not found: there.txt"
        Join-DeploymentPath 'README.md' | Should -Be (Join-Path $PSScriptRoot '../Deployment/README.md')
      }
    }
  }
}
