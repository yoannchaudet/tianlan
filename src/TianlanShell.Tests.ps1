Describe 'Invoke-Tianlan' {
  It 'Propagates default deployment path (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -Command 'Get-DeploymentPath' `
      | Should -Not -BeNullOrEmpty
  }

  It 'Propagates custom deployment path (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -DeploymentPath ([System.IO.Path]::GetTempPath()) -Command 'Get-DeploymentPath' `
      | Should -Be ([System.IO.Path]::GetTempPath())
  }

  It 'Propagates custom deployment path (mode = Docker)' {
    Invoke-Tianlan -Mode 'Docker' -DeploymentPath ([System.IO.Path]::GetTempPath()) -Command 'Get-DeploymentPath' `
      | Should -Be '/tianlan/deployment'
  }

  It 'Loads Tianlan module only (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -Command '(Get-Module -Name Tianlan).Name | Out-String' `
      | Should -Contain 'Tianlan'
    Invoke-Tianlan -Mode 'Host' -Command 'Get-Module -Name TianlanShell' `
      | Should -BeNullOrEmpty
  }

  It 'Loads Tianlan module only (mode = Docker)' {
    Invoke-Tianlan -Mode 'Docker' -Command '(Get-Module -Name Tianlan).Name' `
      | Should -Be 'Tianlan'
    Invoke-Tianlan -Mode 'Docker' -Command 'Get-Module -Name TianlanShell' `
      | Should -BeNullOrEmpty
  }

  It 'Propagates exceptions (mode = Host)' {
    { Invoke-Tianlan -Mode 'Host' -Command 'throw x' } `
      | Should -Throw 'x'
  }

  It 'Propagates exceptions (mode = Docker)' {
    { Invoke-Tianlan -Mode 'Docker' -Command 'throw x' } `
      | Should -Throw 'x'
  }
}

