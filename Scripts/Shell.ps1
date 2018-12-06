# Customize prompt
function prompt() {
  Write-Host 'tianlan>' -ForegroundColor 'Yellow' -NoNewline
  ' '
}

# Set history location
Set-PSReadlineOption -HistorySavePath '/tianlan/.profile/history'