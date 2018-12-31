function New-Environment {
  <#
  .SYNOPSIS Create a new environment.

  .DESCRIPTION
  Create a new environment.

  This script runs in interactive mode. It firsts creates a service principal
  and give it co-admin permissions on the whole subscription.

  Then it creates the environment's Key Vault which is used to store environment
  related secrets.

  .PARAMETER Name
  The environment name.

  .PARAMETER SubscriptionId
  The subscription to connect to and where to create the environment.

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

  # Make sure the environment's admin is not declared already
  $spName = "$Name.admin"
  if (Get-Manifest 'servicePrincipals', $spName) {
    throw "Environment's admin service principal already exists"
  }

  # Connect
  Connect-Azure -SubscriptionId $SubscriptionId

  # Create a new service principal
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
  $manifest = Get-Manifest
  $servicePrincipals = Get-Manifest 'servicePrincipals' -DefaultValue @{}
  $servicePrincipals | Add-Member -MemberType 'NoteProperty' -Name $spName -Value @{
    id                    = $sp.ServicePrincipal.Id
    applicationId         = $sp.ServicePrincipal.ApplicationId
    tenantId              = (Get-AzContext).Tenant.Id
    certificateThumbprint = $sp.Certificate.Thumbprint
  } -Force
  $manifest.servicePrincipals = $servicePrincipals
  $environments = Get-Manifest 'environments' -DefaultValue @{}
  $environments | Add-Member -MemberType 'NoteProperty' -Name $Name -Value @{
    location       = $Location
    subscriptionId = $SubscriptionId
  }
  $manifest.environments = $environments
  Set-Manifest $manifest
  Write-Host 'Done!' -ForegroundColor 'Green'
}