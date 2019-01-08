enum ContextType {
  Environment
}

class DeploymentContext {
  [string] $TemplateName
  [string] $ResourceGroup
  [string] $Location
  [ContextType] $ContextType
  [string] $ContextName
}

function Get-DeploymentContext() {
  <#
  .SYNOPSIS
  Return a deployment context.

  .PARAMETER Environment
  The environment for which to return a context.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment
  )

  # Get the environment definition
  $environmentDef = Get-Manifest 'environments', $Environment

  # Build the context object and return it
  $ctx = [DeploymentContext]::new()
  $ctx.TemplateName = '$Environment'
  $ctx.ResourceGroup = $Environment
  $ctx.Location = $environmentDef.location
  $ctx.ContextType = 'Environment'
  $ctx.ContextName = $Environment
  return $ctx
}

function Get-DeploymentFile() {
  <#
  .SYNOPSIS
  Return the path to a deployment file.

  .DESCRIPTION
  Return the path to a deployment file.

  Look in order at:
  - path.context.extension (context file)
  - path.extension (default file)

  .PARAMETER Context
  The context name.

  .PARAMETER Path
  The path to the file to look for.

  .PARAMETER Extension
  The file extension (without a starting dot).
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Context,
    [Parameter(Mandatory)]
    [string] $Path,
    [Parameter(Mandatory)]
    [string] $Extension
  )

  # Look context file first
  $resolvedPath = Join-DeploymentPath -Path "${Path}.${Context}.${Extension}" -SkipValidation

  # If no context file is found, lookup default file
  if (!(Test-Path -Path $resolvedPath)) {
    $resolvedPath = Join-DeploymentPath -Path "${Path}.${Extension}"
  }
  return $resolvedPath
}

function Get-TemplateParameters {
  <#
  .SYNOPSIS
  Get the template parameters for a given context.

  .DESCRIPTION
  Get the template parameters for a given context.

  Parse the file and build a hashmap out of the parameters.

  .PARAMETER Context
  The deployment context.
  #>

  param (
    [Parameter(Mandatory)]
    [DeploymentContext] $Context
  )

  # Lookup the parameters file
  $file = Get-DeploymentFile `
    -Context $Context.ContextName `
    -Path "Parameters/$($Context.TemplateName)" `
    -Extension 'Parameters.json'

  # Parse file and collect parameters
  $parameters = @{}
  $parsedFile = Get-Content -Raw -Path $file -Encoding 'UTF8' | ConvertFrom-Json
  if ($parsedFile.psobject.properties['parameters']) {
    $parsedFile.parameters.psobject.properties | ForEach-Object {
      if ($parsedFile.parameters.($_.Name).psobject.properties['value']) {
        $parameters[($_.Name)] = $parsedFile.parameters.($_.Name).value
      }
    }
  }
  return $parameters
}

function New-TemplateDeployment {

  param (
    [Parameter(Mandatory)]
    [DeploymentContext] $Context,
    [hashtable] $Parameters
  )

  # WIP

}