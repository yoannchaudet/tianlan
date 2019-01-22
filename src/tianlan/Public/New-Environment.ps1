function New-Environment {
  <#
  .SYNOPSIS
  Declare a new environment.

  .DESCRIPTION
  Declare a new environment.

  Note: this scripts runs in interactive mode. Current user must have Owner permission
  on the subscription.

  .PARAMETER Name
  The environment name.

  .PARAMETER SubscriptionId
  The subscription where to create the environment.

  .PARAMETER Location
  The location where to provision the environment.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $SubscriptionId,
    [Parameter(Mandatory)]
    [string] $Location
  )

  # Make sure the environment is not declared already
  if (Get-Manifest 'environments', $Name) {
    throw 'Environment already exists'
  }

  # Declare the environment
  $envDef = Get-EnvironmentDefinition -Location $Location -SubscriptionId $SubscriptionId
  $manifest = Get-Manifest
  $manifest = $manifest | Add-Property -Properties 'environments', $Name -Value $envDef
  Set-Manifest $manifest

  # Declare the admin identity
  New-ServicePrincipal -Environment $Name -Name 'admin'

  # Assign a role on the service principal
  # Note, we need a retry here because of https://github.com/Azure/azure-powershell/issues/2286
  Write-Host 'Assigning Owner role to service principal (scoped to the subscription)' -ForegroundColor 'Blue'
  $spDef = Get-Manifest 'environments', $Name, 'servicePrincipals', 'admin' -ThrowOnMiss
  Connect-Azure -SubscriptionId $SubscriptionId
  Invoke-Retry {
    New-AzRoleAssignment `
      -RoleDefinitionName 'Owner' `
      -ApplicationId ($spDef.applicationId) `
      -Scope "/subscriptions/$SubscriptionId"
  } -RetryDelay { 10 }
}