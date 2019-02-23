<#
.SYNOPSIS
Profile file for the Tianlan shell.

.DESCRIPTION
Excepts the following environment variables:

- DeploymentPath (required), base64-encoded string with current deployment path (i.e. location of the provided
  deployment related files such as Manifest.json and templates).

- Command (optional), base64-encoded string containing command(s) to run. When provided the shell exits directly.

- CommandOutputPath (optional), file where to save the output of the command to run.
#>

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

# Set local dependencies in scope
$env:PSModulePath = "$(Join-Path $PSScriptRoot 'Dependencies')$([IO.Path]::PathSeparator)$($env:PSModulePath)"

# Import the Tianlan module
Import-Module -Name (Join-Path $PSScriptRoot 'Tianlan.psd1')

# Set the deployment path
Set-DeploymentPath ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:DeploymentPath)))

# Invoke the command
if ($env:Command) {
  $output = Invoke-Expression -Command ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:Command)))
  if ($env:CommandOutputPath) {
    $output | Out-File -FilePath $env:CommandOutputPath -Encoding 'UTF8' -NoNewline
  }
  else {
    $output
  }
}

# Prepare interactive shell
else {
  function global:prompt() {
    <#
    .SYNOPSIS Define a custom prompt.
    #>

    Write-Host 'tianlan>' -NoNewline
    ' '
  }

  # Set custom history location
  $profileLocation = Resolve-Path '~/.tianlan'
  Set-PSReadlineOption -HistorySavePath (Join-Path $profileLocation 'history')
}
