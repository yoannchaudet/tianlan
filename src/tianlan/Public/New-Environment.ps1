function New-Environment {
  <#
  .SYNOPSIS
  Declare and initalize a new environment.

  .DESCRIPTION
  Declare and initialize a new environment.

  Note: this scripts runs in interactive mode. Current user must have Owner permission
  on the subscription and admin permission on the tenant.

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

  # Declare the environment in Manifest
  Write-Host 'Declaring environment...' -ForegroundColor 'Blue'
  $envDef = Get-EnvironmentDefinition -Location $Location -SubscriptionId $SubscriptionId
  $manifest = Get-Manifest
  $manifest = $manifest | Add-Property -Properties 'environments', $Name -Value $envDef
  Set-Manifest $manifest

  # Login
  Connect-Azure -SubscriptionId $SubscriptionId

  # Create a new service principal
  Write-Host 'Creating admin service principal...' -ForegroundColor 'Blue'
  $sp = New-AdServicePrincipal -DisplayName "admin ($Name)" -Admin

  # Declare the service principal in Manifest
  $certificateName = Get-CertificateName 'admin'
  $spDef = Get-ServicePrincipalDefinition -ServicePrincipal $sp -CertificateName $certificateName
  $manifest = Get-Manifest
  $manifest = $manifest | Add-Property -Properties 'environments', $Name, 'servicePrincipals', 'admin' -Value $spDef
  Set-Manifest $manifest

  # Assign a role on the service principal
  # Note, we need a retry here because of https://github.com/Azure/azure-powershell/issues/2286
  Write-Host 'Assigning Owner role to admin service principal...' -ForegroundColor 'Blue'
  $spDef = Get-Manifest 'environments', $Name, 'servicePrincipals', 'admin' -ThrowOnMiss
  Invoke-Retry {
    New-AzRoleAssignment `
      -RoleDefinitionName 'Owner' `
      -ApplicationId ($spDef.applicationId) `
      -Scope "/subscriptions/$SubscriptionId"
  } -RetryDelay { 10 } -MaxRetries 5

  # Logging
  Write-Host 'Environment created successfuly!'
}