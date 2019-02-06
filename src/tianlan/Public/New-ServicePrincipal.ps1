function New-ServicePrincipal {
  <#
  .SYNOPSIS
  Create (and declare) a new service principal.

  .DESCRIPTION
  Create (and declare) a new service principal.

  The service principal is created in the tenant of the
  environment's subscription.

  .PARAMETER Environment
  The environment name.

  .PARAMETER Name
  The environment name.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [Parameter(Mandatory)]
    [string] $Name
  )

  # Make sure the service principal does not exist already
  if (Get-manifest 'environments', $Environment, 'servicePrincipals', $Name) {
    throw 'A service principal with this name already exist for the environment'
  }

  # Login
  Connect-Azure -Environment $Environment

  # Create a new service principal
  Write-Host 'Creating service principal...' -ForegroundColor 'Blue'
  $sp = New-AdServicePrincipal -DisplayName "$Name ($Environment)"
  $sp.ServicePrincipal

  # Update manifest
  Write-Host 'Declaring service principal...' -ForegroundColor 'Blue'
  $certificateName = Get-CertificateName $Name
  $spDef = Get-ServicePrincipalDefinition -ServicePrincipal $sp -CertificateName $certificateName
  $manifest = Get-Manifest
  $manifest = $manifest | Add-Property -Properties 'environments', $Environment, 'servicePrincipals', $Name -Value $spDef
  Set-Manifest $manifest

  # Logging
  Write-Host 'Service principal created successfuly!'
}