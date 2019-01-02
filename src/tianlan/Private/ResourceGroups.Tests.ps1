InModuleScope Tianlan {
  Describe 'New-ResourceGroup' {
    It 'Returns existing resource group' {
      Mock 'Get-AzResourceGroup' { 'existing rg' }
      Mock 'New-AzResourceGroup' {}
      New-ResourceGroup -Name 'name' -Location 'location' | Should -Be 'existing rg'
      Assert-MockCalled 'Get-AzResourceGroup' -Times 1
      Assert-MockCalled 'New-AzResourceGroup' -Times 0
    }

    It 'Creates new resource group if needed' {
      Mock 'Get-AzResourceGroup' {}
      Mock 'New-AzResourceGroup' { 'created rg' }
      New-ResourceGroup -Name 'name' -Location 'location' | Should -Be 'created rg'
      Assert-MockCalled 'Get-AzResourceGroup' -Times 1
      Assert-MockCalled 'New-AzResourceGroup' -Times 1
    }
  }
}