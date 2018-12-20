#!/usr/bin/env pwsh
#Requires -version 5.0

param (
  [string]
  [Parameter(Mandatory=$false)]
  [ValidateSet('Host', 'Docker')] $Mode = 'Host'
)

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

#
# Utilities
#

#
# Main
#

# Create folder to store the container's userprofile
$hostProfile = (Join-Path $env:USERPROFILE '.tianlan')
New-Item -ItemType 'Directory' -Path $hostProfile -Force | Out-Null

# Get the scripts folder
$scriptsFolder = Join-Path $PSScriptRoot 'Scripts'

switch ($Mode) {

  'Host' {
    # Lookup pwsh
    $pwsh = (Get-Command -Name 'pwsh').Source

    # Copy the current prompt
    $promptCopy = Get-Content function:\prompt
    try {
      # Start the shell
      & $pwsh -NoExit -Command ". $(Join-Path $scriptsFolder 'Shell.ps1')"
    } finally {
      # Restore the prompt
      Set-Content function:\prompt $promptCopy
    }
  }

  'Docker' {
    # Lookup docker
    $docker = (Get-Command -Name 'docker').Source

    # Build the image
    $imageName = 'tianlan:local'
    & $docker build $PSScriptRoot -t $imageName | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Shell image build failed"
    }

    # Start the image (or shell)
    & $docker run `
      --volume ${hostProfile}:/tianlan/.profile `
      --volume ${scriptsFolder}:/tianlan/Scripts `
      --rm -it $imageName
  }
}
