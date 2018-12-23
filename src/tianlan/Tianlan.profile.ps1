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

# Expose deployment path
$global:DeploymentPath = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:DeploymentPath))


# Import the module
Import-Module -Name (Join-Path $PSScriptRoot 'Tianlan.psd1')

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

    Write-Host 'tianlan>' -NoNewline
    ' '
  }

  # Set custom history location
  $profileLocation = Resolve-Path '~/.tianlan'
  Set-PSReadlineOption -HistorySavePath (Join-Path $profileLocation 'history')
}
