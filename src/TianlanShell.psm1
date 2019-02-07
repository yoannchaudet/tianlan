#Requires -version 5.0

# Init
Set-StrictMode -version 'Latest'
$ErrorActionPreference = 'Stop'

function ConvertTo-Base64 {
  <#
  .SYNOPSIS
  Convert a string to its base64 reprensentation.

  .PARAMETER InputValue
  The value to convert.

  .PARAMETER Encoding
  Use UTF8 by default. Pwsh when encoding commands expects "Unicode" to be used somehow.
  #>
  param (
    [Parameter(Mandatory=$true)]
    [string] $InputValue,
    [String] $Encoding = 'UTF8'
  )
  [System.Convert]::ToBase64String([System.Text.Encoding]::${Encoding}.GetBytes($InputValue))
}

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

  .PARAMETER Command
  An optional command to run. When provided the shell exits upon completion
  #>

  param (
    [string] [ValidateSet('Host', 'Docker')] $Mode = 'Host',
    [string] $DeploymentPath,
    [string] $Command
  )

  # Initialize deployment path if needed and validate it
  if (!$DeploymentPath) {
    $DeploymentPath = Get-Location
  }
  if (!(Test-Path -LiteralPath $DeploymentPath -PathType 'Container')) {
    throw "Provided deployment path ($DeploymentPath) does not exist or is not a folder"
  }

  # Create folder to store the container's userprofile
  $hostProfile = (Join-Path ~ '.tianlan')
  New-Item -ItemType 'Directory' -Path $hostProfile -Force | Out-Null

  # Get the module folder
  $moduleFolder = Join-Path $PSScriptRoot 'tianlan'

  # Prepare args for the pwsh command to run
  $args = @('-NoProfile')
  if (!$Command) {
    $args += '-NoExit'
  }
  if ($Mode -eq 'Host') {
    $args += @('-EncodedCommand', "$(ConvertTo-Base64 -Encoding Unicode ". $(Join-Path $moduleFolder 'Tianlan.profile.ps1')")")
  } else {
    $args += @('-EncodedCommand', "$(ConvertTo-Base64 -Encoding Unicode ". /tianlan/module/Tianlan.profile.ps1")")
  }

  # Prepare environment
  if ($Command) {
    $env:Command = ConvertTo-Base64 $Command
  } else {
    $env:Command = ''
  }

  # Invoke the requested mode
  switch ($Mode) {
    'Host' {
      # Lookup pwsh
      $pwsh = (Get-Command -Name 'pwsh').Source

      # Prepare environment
      $env:DeploymentPath = ConvertTo-Base64 $DeploymentPath

      # Start the shell
      & $pwsh $args
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

      # Create a local volume if needed
      # This is used to persist the .dotnet profile folder
      # It is mounted as a local volume because it is sensitive to file permissions and required (e.g. on a Windows host)
      if (!($(& $docker volume ls --format '{{.Name}}') | Where-Object { $_ -eq 'tianlan-dotnet' })) {
        docker volume create --driver=local tianlan-dotnet
      }

      # Start the image (or shell)
      & $docker run `
        --volume ${hostProfile}:/root/.tianlan `
        --volume ${moduleFolder}:/tianlan/module `
        --volume ${DeploymentPath}:/tianlan/deployment `
        --volume tianlan-dotnet:/root/.dotnet:rw `
        -e DeploymentPath=$(ConvertTo-Base64 /tianlan/deployment) `
        -e Command=$env:Command `
        --rm -it $imageName $args
    }
  }
}
