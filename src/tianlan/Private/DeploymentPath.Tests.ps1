InModuleScope Tianlan {
  Context "Set deployment path" {
    BeforeAll {
      Set-DeploymentPath 'testdrive:'
    }

    Describe 'Join-DeploymentPath' {
      BeforeEach {
        # Add some files there too
        'hello here' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'here.txt')
        New-Item -Path (Join-Path (Get-DeploymentPath) 'f') -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
        'hello there' | Out-File -FilePath (Join-Path (Get-DeploymentPath) 'f/there.txt')
      }

      It "Join paths with validation" {
        Join-DeploymentPath 'here.txt' | Should -Be (Join-Path (Get-DeploymentPath) 'here.txt')
        Join-DeploymentPath 'f/there.txt' | Should -Be (Join-Path (Get-DeploymentPath) 'f/there.txt')
        { Join-DeploymentPath 'there.txt' } | Should -Throw "Deployment path not found: $(Join-Path (Get-DeploymentPath) 'there.txt')"
      }

      It "Join paths without validation" {
        Join-DeploymentPath 'hello' -SkipValidation | Should -Be (Join-Path (Get-DeploymentPath) 'hello')
        Join-DeploymentPath 'hello/my/friend' -SkipValidation | Should -Be (Join-Path (Get-DeploymentPath) 'hello/my/friend')
      }
    }
  }
}
