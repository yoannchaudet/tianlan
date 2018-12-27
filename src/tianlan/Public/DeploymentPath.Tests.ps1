InModuleScope Tianlan {
  Describe 'DeploymentPath' {
    It 'Has getter/setter' {
      Set-DeploymentPath 'testdrive:'
      Get-DeploymentPath | Should -Be 'testdrive:'
    }

    It 'Validates input' {
      { Set-DeploymentPath 'testdrive:/xxx' } | Should -Throw 'Provided deployment path does not exist or is not a folder'
    }
  }
}