# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

# Dot-source all the files (outside the tests)
foreach ($folderName in @('Private', 'Public')) {
  $path = Join-Path (Join-Path $PSScriptRoot $folderName) '*.ps1'
  foreach ($file in @(Get-ChildItem -Path $path -Exclude '*.Tests.ps1')) {
    try {
      . $file.FullName
    } catch {
      Write-Error "Failed to import file ($($file.FullName))`n$_"
    }
  }
}

# Let the psd1 file decide what to export (best performance and cleaner).