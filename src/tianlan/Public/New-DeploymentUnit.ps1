function New-DeploymentUnit {
  <#
  .SYNOPSIS
  Declare a new deployment unit..

  .PARAMETER Environment
  The environment name.

  .PARAMETER Name
  The deployment unit name.

  .PARAMETER Location
  The location where to provision the deployment unit.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $Location
  )

  # Make sure the environment exists and the deployment unit not already declared
  if (!(Get-Manifest 'environments', $Environment)) {
    throw 'Environment does not exist'
  }
  if (Get-Manifest 'environments', $Environment, 'deploymentUnits', $Name) {
    throw 'Deployment unit already exists'
  }

  # Declare the deployment unit
  Invoke-Step 'Declaring deployment unit' {
    # Get current manifest
    $manifest = Get-Manifest

    # Declare deployment unit
    $duDef = Get-DeploymentUnitDefinition -Location $Location
    $manifest = $manifest | Add-Property -Properties 'environments', $Environment, 'deploymentUnits', $Name -Value $duDef

    # Save manifest
    Set-Manifest $manifest
  }
}