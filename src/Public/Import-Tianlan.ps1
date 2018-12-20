
function Import-Tianlan() {
  <#
  .SYNOPSIS
  Import (or re-import) the Tianlan module.

  .DESCRIPTION
  This function may be called in order to apply module changes
  in an active session (e.g. during development).

  .PARAMETER Verbose
  Switch to enable verbose import.
  #>

  param (
    [switch] $Verbose
  )

  # Remove the module (if loaded)
  Remove-Module -Name 'Tianlan' -Force -ErrorAction 'SilentlyContinue'

  # Import it again
  $moduleRoot = Join-Path (Join-Path $PSScriptRoot '..') 'Tianlan.psd1'
  Import-Module -Name $moduleRoot -Scope 'Global' -Verbose:$Verbose
}