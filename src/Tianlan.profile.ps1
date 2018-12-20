<#
.SYNOPSIS Profile file for the Tianlan shell.
#>

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