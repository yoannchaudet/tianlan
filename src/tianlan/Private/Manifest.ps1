# Manifest utilities

function Join-DeploymentPath {
  <#
  .SYNOPSIS
  Join a given path with the current deployment path.

  .PARAMETER Path
  The path to join with the current deployment path.

  .PARAMETER SkipValidation
  Switch to disable validation.
  #>

  param (
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [switch] $SkipValidation
  )

  # Build the joined-path
  $joinedPath = Join-Path $global:DeploymentPath $Path

  # Validate the path
  if (!$SkipValidation -and !(Test-Path -Path $joinedPath)) {
    throw "Deployment path not found: $joinedPath"
  }
  return $joinedPath
}

function Get-DefaultManifest {
  <#
  .SYNOPSIS
  Return a default manifest.
  #>

  # Return a default (empty) manifest file
  '{
    "servicePrincipals": {}
  }' | ConvertFrom-Json
}

function Get-Manifest {
  <#
  .SYNOPSIS
  Return the current Manifest.json file.
  #>

  # Get the manifest file path
  $manifestFile = Join-DeploymentPath 'Manifest.json' -SkipValidation

  # Parse the manifest
  if (Test-Path $manifestFile) {
    Get-Content -Raw -Path $manifestFile | ConvertFrom-Json
  }

  # Return a default (empty) manifest
  else {
    Get-DefaultManifest
  }
}
