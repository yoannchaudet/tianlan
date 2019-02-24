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

  # Make sure the environment exists
  if (!(Get-Manifest 'environments', $Name)) {
    throw 'Environment does not exist'
  }

  # Make sure the service principal does not exist already
  if (Get-manifest 'environments', $Environment, 'servicePrincipals', $Name) {
    throw 'A service principal with this name already exist for the environment'
  }

  # Login
  Invoke-Step 'Authenticating' {
    Connect-Azure -Environment $Environment
  }

  # Create a new service principal
  $sp = Invoke-Step 'Creating service principal' {
    New-AdServicePrincipal -DisplayName "$Name ($Environment)"
  }
  $sp.ServicePrincipal

  # Update manifest
  Invoke-Step 'Updating manifest' {
    # Get current manifest
    $manifest = Get-Manifest

    # Declare service principal
    $certificateName = Get-CertificateName $Name
    $spDef = Get-ServicePrincipalDefinition -ServicePrincipal $sp -CertificateName $certificateName
    $manifest = $manifest | Add-Property -Properties 'environments', $Environment, 'servicePrincipals', $Name -Value $spDef

    # Save manifest
    Set-Manifest $manifest
  }
}