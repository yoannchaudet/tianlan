#!/usr/bin/env pwsh
#Requires -version 5.0

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

#
# Utilities
#

function Get-Docker() {
  <#
  .SYNOPSIS
  Return the Docker executable filename or throw an exception.
  #>
  $docker = Get-Command -Name 'docker' -ErrorAction 'Ignore'
  if ($docker) {
    return $docker.Source
  }
  else {
    throw "Unable to locate Docker on the system"
  }
}

#
# Main
#

# Lookup docker
$docker = Get-Docker

# Create folder to store the container's userprofile
$hostProfile = (Join-Path $env:USERPROFILE '.tianlan')
New-Item -ItemType 'Directory' -Path $hostProfile -Force | Out-Null

# Build the image
$imageName = 'tianlan:local'
& $docker build $PSScriptRoot -t $imageName

# Start the image (or shell)
$scriptsFolder = Join-Path $PSScriptRoot 'Scripts'
& $docker run `
  --volume ${hostProfile}:/tianlan/.profile `
  --volume ${scriptsFolder}:/tianlan/Scripts `
  --rm -it $imageName