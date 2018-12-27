function Get-DeploymentPath {
  <#
  .SYNOPSIS
  Return the current deployment path.
  #>

  $global:TIANLIN_DEPLOYMENTPATH
}

function Set-DeploymentPath {
  <#
  .SYNOPSIS
  Set the current deployment path.

  .PARAMETER DeploymentPath
  The deployment path to set (i.e. where to locate user files such as Manifest, templates, etc.).
  #>

  param (
    [Parameter(Mandatory = $true)]
    [string] $DeploymentPath
  )

  # Validate the deployment path is a folder
  if (!(Test-Path -Path $DeploymentPath -PathType 'Container')) {
    throw 'Provided deployment path does not exist or is not a folder'
  }
  $global:TIANLIN_DEPLOYMENTPATH = $DeploymentPath
}