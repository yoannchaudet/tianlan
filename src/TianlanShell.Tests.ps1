Describe 'Invoke-Tianlan' {
  It 'Propagates default deployment path (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -Command 'Get-DeploymentPath | Out-String' | Should -Not -BeNullOrEmpty
  }

  It 'Propagates custom deployment path (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -DeploymentPath ([System.IO.Path]::GetTempPath()) -Command 'Get-DeploymentPath | Out-String' `
      | Should -Contain ([System.IO.Path]::GetTempPath())
  }

  It 'Propagates custom deployment path (mode = Docker)' {
    Invoke-Tianlan -Mode 'Docker' -DeploymentPath ([System.IO.Path]::GetTempPath()) -Command 'Get-DeploymentPath | Out-String' `
      | Where-Object { $_ } `
      | ForEach-Object { $_ -Replace '\x1b\[[0-9;]*m','' } `
      | Should -Match '/tianlan/deployment'
  }

  It 'Loads Tianlan module only (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -Command '(Get-Module -Name Tianlan).Name | Out-String' `
      | Should -Contain 'Tianlan'
    Invoke-Tianlan -Mode 'Host' -Command '(Get-Module -Name TianlanShell).Name | Out-String' `
      | Should -BeNullOrEmpty
  }

  It 'Loads Tianlan module only (mode = Docker)' {
    Invoke-Tianlan -Mode 'Docker' -Command '(Get-Module -Name Tianlan).Name | Out-String' `
      | Where-Object { $_ } `
      | Should -Match 'Tianlan'
    Invoke-Tianlan -Mode 'Docker' -Command '(Get-Module -Name TianlanShell).Name | Out-String' `
      | Where-Object { $_ } `
      | ForEach-Object { $_ -Replace '\x1b\[[0-9;]*m','' } `
      | Should -Not -Match 'TianlanShell'
  }
}

