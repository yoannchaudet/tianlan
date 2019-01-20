InModuleScope Tianlan {
  Describe 'Import-Tianlan' {
    It 'Calls remove/import module' {
      Mock 'Remove-Module' {} -ParameterFilter { $Name -eq 'Tianlan' }
      Mock 'Import-Module' {} -ParameterFilter { $Name.EndsWith('Tianlan.psd1') -and (Test-Path $Name) }
      Import-Tianlan
      Assert-MockCalled 'Remove-Module' -Times 1
      Assert-MockCalled 'Import-Module' -Times 1
    }
  }
}