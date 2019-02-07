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

# Configure docker-in-docker
$extraOptions = ""
if ($IsWindows) {
  $extraOptions = "-e DOCKER_HOST='tcp://docker.for.win.localhost:2375'"
} else {
  $extraOptions = "--volume /var/run/docker.sock:/var/run/docker.sock "
}

# Run the build script
$expression = "& '$docker' run "
$expression += "--volume ${PSScriptRoot}:/build "
$expression += "--volume ${BuildVolumePath}:/build-tmp "
$expression += "--workdir /build "
$expression += "$extraOptions "
$expression += "--rm $imageName /build/build.ps1 $Parameters"
Invoke-Expression $expression
