<#
.SYNOPSIS
Profile file for the Tianlan shell.

.PARAMETER DeploymentPath
Deployment folder where Manifest.json file, templates and generally all
files that can be customized are located.
#>

param (
  [string] $DeploymentPath
)

# Expose deployment path
$global:DeploymentPath = $DeploymentPath

function prompt() {
  <#
  .SYNOPSIS Define a custom prompt.
  #>

  Write-Host 'tianlan>' -NoNewline
  ' '
}

# Set custom history location
$profileLocation = Resolve-Path '~/.tianlan'
Set-PSReadlineOption -HistorySavePath (Join-Path $profileLocation 'history')

# Import the module
Import-Module -Name (Join-Path $PSScriptRoot 'Tianlan.psd1')