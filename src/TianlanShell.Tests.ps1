Describe 'Invoke-Tianlan' {
  It 'Propagates default deployment path (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -Command 'Get-DeploymentPath | Out-String' | Should -Not -BeNullOrEmpty
  }

  It 'Propagates custom deployment path (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -DeploymentPath ([System.IO.Path]::GetTempPath()) -Command 'Get-DeploymentPath' `
      | Should -Contain ([System.IO.Path]::GetTempPath())
  }

  It 'Propagates custom deployment path (mode = Docker)' {
    (Invoke-Tianlan -Mode 'Docker' -DeploymentPath ([System.IO.Path]::GetTempPath()) -Command 'Get-DeploymentPath').Contains('/tianlan/deployment') `
      | Should -BeTrue
  }

  It 'Loads Tianlan module only (mode = Host)' {
    Invoke-Tianlan -Mode 'Host' -Command '(Get-Module -Name Tianlan).Name' `
      | Should -Contain 'Tianlan'
    Invoke-Tianlan -Mode 'Host' -Command '(Get-Module -Name TianlanShell).Name' `
      | Should -BeNullOrEmpty
  }

  It 'Loads Tianlan module only (mode = Docker)' {
    (Invoke-Tianlan -Mode 'Docker' -Command '(Get-Module -Name Tianlan).Name').Contains('Tianlan') `
      | Should -BeTrue
    (Invoke-Tianlan -Mode 'Docker' -Command '(Get-Module -Name TianlanShell).Name').Contains('TianlanShell') `
      | Should -BeFalse
  }
}

