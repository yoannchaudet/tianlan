function New-ResourceGroup {
  <#
  .SYNOPSIS
  Create a resource group if it does not exist already.

  .PARAMETER Name
  Resource group name.

  .PARAMETER Location
  Resource group location (only for metadata).
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $Location
  )

  # Create resource group if it does not exist already
  $resourceGroup = Get-AzResourceGroup -Name $Name -ErrorAction 'SilentlyContinue'
  if (!$resourceGroup) {
    $resourceGroup = New-AzResourceGroup -Name $Name -Location $Location
  }
  return $resourceGroup
}