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

  .PARAMETER Filters
  Optional string array of properties to follow in the Manifest.
  When provided, returns the matching property if possible.

  .PARAMETER DefaultValue
  When Filters is provided, set the value to return in case the filter
  fails. Default to null.
  #>

  param (
    [Parameter(Position=0, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null
  )

  # Get the manifest file path
  $manifestFile = Join-DeploymentPath 'Manifest.json' -SkipValidation

  # Parse the manifest
  if (Test-Path $manifestFile) {
    $manifest = Get-Content -Raw -Path $manifestFile | ConvertFrom-Json
  }

  # Return a default (empty) manifest
  else {
    $manifest = Get-DefaultManifest
  }

  # Select requested part of the manifest (if needed)
  if ($Filters) {
    foreach ($segment in $Filters) {
      if ($manifest -and $manifest.psobject.Properties[$segment]) {
        $manifest = $manifest.$segment
      } else {
        $manifest = $DefaultValue
        break
      }
    }
  }

  # Return the manifest
  return $manifest
}
