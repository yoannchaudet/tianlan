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

  # Connect
  Connect-Azure -SubscriptionId $SubscriptionId

  # Create a new service principal
  $spName = "${Name}.admin"
  Write-Host "Creating service principal $spName..." -ForegroundColor 'Blue'
  $sp = New-ServicePrincipal -DisplayName $spName
  $sp.ServicePrincipal

  # Assign a role on the service principal
  # Note, we need a retry here because of https://github.com/Azure/azure-powershell/issues/2286
  Write-Host 'Assigning Owner role to service principal (scoped to the subscription)' -ForegroundColor 'Blue'
  Invoke-Retry {
    New-AzRoleAssignment `
      -RoleDefinitionName 'Owner' `
      -ApplicationId ($sp.ServicePrincipal.ApplicationId) `
      -Scope "/subscriptions/$SubscriptionId"
  } -RetryDelay { 5 }

  # Update the Manifest file
  Write-Host 'Updating Manifest file' -ForegroundColor 'Blue'
  $environmentDef = Get-EnvironmentDefinition `
    -Location $Location `
    -SubscriptionId $SubscriptionId `
    -AdminServicePrincipalDefinition (Get-ServicePrincipalDefinition -ServicePrincipal $sp -CertificateName 'Admin-Certificate')
  $manifest = Get-Manifest
  $manifest.environments = Add-ManifestProperty `
    -Manifest (Get-Manifest 'environments' -DefaultValue @{}) `
    -Property $Name `
    -Value $environmentDef
  Set-Manifest $manifest
  Write-Host 'Done!' -ForegroundColor 'Green'
}