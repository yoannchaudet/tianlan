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
    [Parameter(Mandatory)]
    [string] $Path,
    [switch] $SkipValidation
  )

  # Build the joined-path
  $joinedPath = Join-Path (Get-DeploymentPath) $Path

  # Validate the path
  if (!$SkipValidation -and !(Test-Path -Path $joinedPath)) {
    throw "Deployment path not found: $joinedPath"
  }
  return $joinedPath
}