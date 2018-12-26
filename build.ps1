#!/usr/bin/env pwsh
#Requires -Version 6.1 -Modules @{ ModuleName='Pester'; ModuleVersion='4.4.3' }

<#
.SYNOPSIS
Build script for Tianlan.

.PARAMETER Task
The task to run.

- Build, not implemented
- Test, run unit tests
- Import, import the two modules (TianlanShell and Tianlan) in the
  current session (useful during development)

.PARAMETER Parameters
Extra parameters to pass to the task.
#>

param (
  [ValidateSet('Build', 'Test', 'Import')]
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

# Switch task
switch ($Task) {
  'Build' {
    throw 'Not implemented'
  }

  'Test' {
    Import-Modules
    Invoke-Pester @Parameters
  }

  'Import' {
    Import-Modules
  }
}