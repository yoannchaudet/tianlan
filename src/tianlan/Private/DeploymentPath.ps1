function Join-DeploymentPath {
  <#
  .SYNOPSIS
  Get the location of a deployment file.

  .DESCRIPTION
  Get the location of a deploymetn file.

  Files are looked up in the following locations (in order):

  - user provided deployment path (i.e. path used when invoking the shell)
  - default deployment path (in this repository)

  .PARAMETER Path
  The path to join with the deployment folder.

  .PARAMETER SkipValidation
  Switch to disable existence validation.

  NOTE: when validation is disabled, the default deployment path is not considered.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Path,
    [switch] $SkipValidation
  )

  # Try to lookup file in the user provided deployment path first
  $joinedPath = Join-Path (Get-DeploymentPath) $Path
  if (!$SkipValidation -and !(Test-Path -Path $joinedPath)) {

    # Try to lookup file in the default deployment path
    $joinedPath = Join-Path $PSScriptRoot "../Deployment/$Path"
    if (!(Test-Path -Path $joinedPath)) {
      throw "Deployment path not found: $Path"
    }
  }

  # Return the path
  return $joinedPath
}