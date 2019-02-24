function New-Stamp {
  <#
  .SYNOPSIS
  Declare a new stamp.

  .PARAMETER Environment
  The environment name.

  .PARAMETER Name
  The stamp name.

  .PARAMETER Location
  The location where to provision the stamp.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $Location
  )

  # Make sure the environment exists and the stamp is not already declared
  if (!(Get-Manifest 'environments', $Environment)) {
    throw 'Environment does not exist'
  }
  if (Get-Manifest 'environments', $Environment, 'stamps', $Name) {
    throw 'Stamp already exists'
  }

  # Declare the stamp
  Invoke-Step 'Declaring stamp' {
    # Get current manifest
    $manifest = Get-Manifest

    # Declare stamp
    $duDef = Get-StampDefinition -Location $Location
    $manifest = $manifest | Add-Property -Properties 'environments', $Environment, 'stamps', $Name -Value $duDef

    # Save manifest
    Set-Manifest $manifest
  }
}