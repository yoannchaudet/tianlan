#!/usr/bin/env pwsh
#Requires -Version 6.1

<#
.SYNOPSIS
Run Tianlan build script in a container.

.PARAMETER Parameters
Parameters to pass to the container.

.PARAMETER BuildVolumePath
A temporary build volume to mount in the container. Can be used to share files with the container.
#>

param (
  [Parameter(Position = 0, ValueFromRemainingArguments)]
  [array] $Parameters,
  [string] $BuildVolumePath = [System.IO.Path]::GetTempPath()
)

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

# Lookup docker
$docker = (Get-Command -Name 'docker').Source

# Build the image
$imageName = 'build.tianlan:local'
& $docker build $PSScriptRoot -t $imageName -f (Join-Path $PSScriptRoot 'build.Dockerfile')
if ($LASTEXITCODE -ne 0) {
  throw 'Image build failed'
}

# Run the build script
& $docker run `
  --volume ${PSScriptRoot}:/build `
  --volume ${BuildVolumePath}:/build-tmp `
  --workdir /build `
  --rm `
  $imageName /build/build.ps1 $Parameters