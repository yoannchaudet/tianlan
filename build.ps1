#!/usr/bin/env pwsh
#Requires -Version 6.1 -Modules @{ ModuleName='Pester'; ModuleVersion='4.6.0' }

<#
.SYNOPSIS
Build script for Tianlan.

.PARAMETER Task
The task to run.

- Build, pull dependencies
- Test, run unit tests
- CodeCoverage, generate a test code coverage report
- Import, import the two modules (TianlanShell and Tianlan) in the current session (useful during development)

.PARAMETER Parameters
Extra parameters to pass to the task.
#>

param (
  [ValidateSet('Build', 'Test', 'TestCodeCoverage', 'Import')]
  [Parameter(Position = 0)]
  [string] $Task = 'Build',
  [hashtable] $Parameters = @{}
)

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

function Import-Modules() {
  Remove-Module -Name 'TianlanShell' -Force -ErrorAction 'SilentlyContinue'
  Remove-Module -Name 'Tianlan' -Force -ErrorAction 'SilentlyContinue'
  Import-Module -Name (Join-Path $PSScriptRoot 'src/TianlanShell.psd1')
  Import-Module -Name (Join-Path $PSScriptRoot 'src/tianlan/Tianlan.psd1')
}

# Handle code coverage
if ($Task -eq 'TestCodeCoverage') {
  $Parameters['CodeCoverage'] = Get-ChildItem `
    -Path (Join-Path $PSScriptRoot 'src') `
    -Include '*.ps1' `
    -Exclude '*.Tests.ps1', 'Tianlan.profile.ps1' `
    -Recurse `
    | Select-Object { $_.FullName } -ExpandProperty 'FullName'
  $Task = 'Test'
}

# Switch task
switch ($Task) {
  'Build' {
    # List of dependencies
    $dependencies = @(
      @{Name = 'Az'; MinimumVersion = '1.2.1'},
      @{Name = 'SelfSignedCertificate'; MinimumVersion = '0.0.4'}
    )

    # Install the dependencies from PSGallery if needed
    $dependenciesPath = Join-Path $PSScriptRoot 'src/tianlan/Dependencies'
    foreach ($dependency in $dependencies) {
      # Ignore available dependency
      if (Test-Path (Join-Path $dependenciesPath "$($dependency.Name)/$($dependency.MinimumVersion)")) {
        Write-Host "[  available  ] $($dependency.Name) (minimum version: $($dependency.MinimumVersion))"
        continue
      }

      # Download dependency
      Write-Host  "[ downloading ] $($dependency.Name) (minimum version: $($dependency.MinimumVersion))"
      Save-Module `
        -Name $dependency.Name `
        -MinimumVersion $dependency.MinimumVersion `
        -Path $DependenciesPath `
        -Repository 'PSGallery'
    }
  }

  'Test' {
    $env:PSModulePath = "$(Join-Path $PSScriptRoot 'src/tianlan/Dependencies')$([IO.Path]::PathSeparator)$($env:PSModulePath)"
    Import-Modules
    Invoke-Pester @Parameters
  }

  'Import' {
    Import-Modules
  }
}