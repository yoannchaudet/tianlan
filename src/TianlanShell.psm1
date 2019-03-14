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
    [Parameter(Mandatory = $true)]
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
  # Get the temp folder
  $tempPath = [System.IO.Path]::GetTempPath()
  $containerOutputFile = "$((New-Guid).Guid).tianlan.out"

  # Prepare args for the pwsh command to run
  $args = @('-NoProfile')
  if (!$Command) {
    $args += '-NoExit'
  }
  if ($Mode -eq 'Host') {
    $args += @('-OutputFormat', 'Text', '-EncodedCommand', "$(ConvertTo-Base64 -Encoding Unicode "& { . $(Join-Path $moduleFolder 'Tianlan.profile.ps1') }")")
  }
  else {
    $args += @('-OutputFormat', 'Text', '-EncodedCommand', "$(ConvertTo-Base64 -Encoding Unicode "& { . /tianlan/module/Tianlan.profile.ps1 }")")
  }

  # Prepare environment
  if ($Command) {
    $env:Command = ConvertTo-Base64 $Command
  }
  else {
    $env:Command = ''

    # Clear the console (this will make sure Invoke-Step properly work with the current host)
    Clear-Host
  }

  # Invoke the requested mode
  switch ($Mode) {
    'Host' {
      # Lookup pwsh
      $pwsh = (Get-Command -Name 'pwsh').Source

      # Prepare environment
      $env:DeploymentPath = ConvertTo-Base64 $DeploymentPath

      # Start the shell
      try {
        # Run the shell directly (interactive)
        if (!$Command) {
          & $pwsh $args
        }

        # Run the shell and collect the output (non-interactive)
        else {
          $rawOutput = & $pwsh $args
          if ($LASTEXITCODE -ne 0) {
            throw $rawOutput
          }
          $rawOutput | Write-Output
        }
      }
      catch {
        $_ | Out-String | Write-Error
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

      # Create a local volume if needed
      # This is used to persist the .dotnet profile folder
      # It is mounted as a local volume because it is sensitive to file permissions and required (e.g. on a Windows host)
      if (!($(& $docker volume ls --format '{{.Name}}') | Where-Object { $_ -eq 'tianlan-dotnet' })) {
        & $docker volume create --driver=local tianlan-dotnet | Out-Null
      }

      # Start the image (or shell)
      $interactiveOptions = '-it'
      if ($env:Command) {
        $interactiveOptions = '-t'
      }
      try {
        # Run the shell directly (interactive)
        if (!$Command) {
          & $docker run `
            --volume ${hostProfile}:/root/.tianlan `
            --volume ${moduleFolder}:/tianlan/module `
            --volume ${DeploymentPath}:/tianlan/deployment `
            --volume ${tempPath}:/tianlan/tmp `
            --volume tianlan-dotnet:/root/.dotnet:rw `
            -e DeploymentPath="$(ConvertTo-Base64 '/tianlan/deployment')" `
            -e Command="${env:Command}" `
            -e CommandOutputPath="$(Join-Path '/tianlan/tmp' $containerOutputFile)" `
            --rm $interactiveOptions $imageName $args
        }

        # Run the shell and collect the output (non-interactive)
        else {
          $rawOutput = & $docker run `
            --volume ${hostProfile}:/root/.tianlan `
            --volume ${moduleFolder}:/tianlan/module `
            --volume ${DeploymentPath}:/tianlan/deployment `
            --volume ${tempPath}:/tianlan/tmp `
            --volume tianlan-dotnet:/root/.dotnet:rw `
            -e DeploymentPath="$(ConvertTo-Base64 '/tianlan/deployment')" `
            -e Command="${env:Command}" `
            -e CommandOutputPath="$(Join-Path '/tianlan/tmp' $containerOutputFile)" `
            --rm $interactiveOptions $imageName $args
          if ($LASTEXITCODE -ne 0) {
            $rawOutput | Out-String | Write-Error
          }
          else {
            # (Explicitly) forward the output
            Get-Content -Path (Join-Path $tempPath $containerOutputFile) -Encoding 'UTF8' -Raw | Write-Output
          }
        }
      }
      finally {
        Remove-Item -Path (Join-Path $tempPath $containerOutputFile) -Force -ErrorAction 'SilentlyContinue'
      }
    }
  }
}
