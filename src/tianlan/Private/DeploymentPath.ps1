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

  .PARAMETER ThrowOnMiss
  Throw an exception if the path cannot be resolved.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Path,
    [switch] $ThrowOnMiss
  )

  # Paths to tests in order
  $paths = @(
    (Join-Path (Get-DeploymentPath) $Path),
    (Join-Path $PSScriptRoot "../Deployment/$Path")
  )

  # Return the first path that exists
  foreach ($testPath in $paths) {
    if (Test-Path -Path $testPath) {
      return $testPath
    }
  }

  # Throw if requested
  if ($ThrowOnMiss) {
    throw "Deployment path not found: $Path"
  }
}