#Requires -version 5.0

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

function Invoke-Tianlan {

  <#
  .SYNOPSIS
  Invoke Tianlan in a dedicated shell.

  .PARAMETER Mode
  The mode in which to start the shell:

  - Host, run a regular shell (in a dedicated pwsh session)
  - Docker, run the shell in a Docker container (self-contained)

  .PARAMETER DeploymentPath
  Deployment folder where Manifest.json file, templates and generally all
  files that can be customized are located.

  Set to current location if not provided.
  #>

  param (
    [string] [ValidateSet('Host', 'Docker')] $Mode = 'Host',
    [string] $DeploymentPath
  )

  # Initialize deployment path if needed and validate it
  if (!$DeploymentPath) {
    $DeploymentPath = Get-Location
  }
  if (!(Test-Path -LiteralPath $DeploymentPath -PathType 'Container')) {
    throw "Provided deployment path ($DeploymentPath) does not exist or is not a folder"
  }

  # Create folder to store the container's userprofile
  $hostProfile = (Join-Path $env:USERPROFILE '.tianlan')
  New-Item -ItemType 'Directory' -Path $hostProfile -Force | Out-Null

  # Get the module folder
  $moduleFolder = Join-Path $PSScriptRoot 'tianlan'

  # Invoke the requested mode
  switch ($Mode) {
    'Host' {
      # Lookup pwsh
      $pwsh = (Get-Command -Name 'pwsh').Source

      # Copy the current prompt
      $promptCopy = Get-Content function:\prompt
      try {
        # Start the shell
        & $pwsh -NoExit -Command ". $(Join-Path $moduleFolder 'Tianlan.profile.ps1') -DeploymentPath $DeploymentPath"
      }
      finally {
        # Restore the prompt
        Set-Content function:\prompt $promptCopy
      }
    }

    'Docker' {
      # Lookup docker
      $docker = (Get-Command -Name 'docker').Source

      # Build the image
      $imageName = 'tianlan:local'
      & $docker build $moduleFolder -t $imageName -f (Join-Path $moduleFolder 'Dockerfile') | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw "Shell image build failed"
      }

      # Start the image (or shell)
      & $docker run `
        --volume ${hostProfile}:/root/.tianlan `
        --volume ${moduleFolder}:/tianlan/module `
        --volume ${DeploymentPath}:/tianlan/deployment `
        --rm -it $imageName
    }
  }
}
