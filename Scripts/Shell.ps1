function prompt() {
  <#
  .SYNOPSIS Define a custom prompt.
  #>
  Write-Host 'tianlan>' -NoNewline
  ' '
}

# Set history location
$profileLocation = Resolve-Path '~/.tianlan'
Set-PSReadlineOption -HistorySavePath (Join-Path $profileLocation 'history')