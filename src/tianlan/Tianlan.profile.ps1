<#
.SYNOPSIS
Profile file for the Tianlan shell.

.DESCRIPTION
Excepts the following environment variables:

- DeploymentPath (required), base64-encoded string with current
  deployment path (i.e. location of the provided deployment related files such as Manifest.json
  and templates).

- Command (optional), base64-encoded string containing command(s) to run.
  When provided the shell exits directly.
#>

# Import the module
Import-Module -Name (Join-Path $PSScriptRoot 'Tianlan.psd1')

# Set the deployment path
Set-DeploymentPath ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:DeploymentPath)))

# Invoke the command
if ($env:Command) {
  Invoke-Expression -Command ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:Command)))
}

# Prepare interactive shell
else {
  function prompt() {
    <#
    .SYNOPSIS Define a custom prompt.
    #>

    Write-Host 'tianlan' -NoNewline
    if ($global:TIANLIN_AUTHCONTEXT) { Write-Host " $global:TIANLIN_AUTHCONTEXT" -NoNewline }
    Write-Host '>' -NoNewline
    ' '
  }

  # Set custom history location
  $profileLocation = Resolve-Path '~/.tianlan'
  Set-PSReadlineOption -HistorySavePath (Join-Path $profileLocation 'history')
}
