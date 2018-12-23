#!/usr/bin/env pwsh
#Requires -version 6

<#
.SYNOPSIS
Build script for Tianlan.

.PARAMETER Task
The task to run.

- Build, not implemented
- Test, run unit tests
- Import, import the two modules (TianlanShell and Tianlan) in the
  current session
#>

param (
  [ValidateSet('Build', 'Test', 'Import')]
  [string] $Task = 'Build'
)

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

function Import-Modules() {
  Remove-Module -Name 'TianlanShell' -Force -ErrorAction 'SilentlyContinue'
  Remove-Module -Name 'Tianlan' -Force -ErrorAction 'SilentlyContinue'
  Import-Module -Name (Join-Path $pwd 'src/TianlanShell.psd1')
  Import-Module -Name (Join-Path $pwd 'src/tianlan/Tianlan.psd1')
}

# Switch task
switch ($Task) {
  'Build' {
    throw 'Not implemented'
  }

  'Test' {
    Import-Modules
    Invoke-Pester
  }

  'Import' {
    Import-Modules
  }
}