#
# Types
#

class Context {
  # Context name
  [string] $Name
  # Hash
  [string] $Hash
  # Key vault name
  [string] $VaultName
}

class DeploymentContext {
  # Name of the template
  [string] $TemplateName
  # Resource group
  [string] $ResourceGroup
  # Location
  [string] $Location
  # Deployment context (available in ARM templates)
  [Context] $Context
}

#
# Functions
#

function Get-VaultName() {
  <#
  .SYNOPSIS
  Return the name of the environment's key vault.

  .PARAMETER Environment
  The environment name.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment
  )

  return "vault$(Get-Hash $Environment)"
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
  $ctx.Context = [Context]::new()
  $ctx.Context.Name = $Environment
  $ctx.Context.Hash = Get-Hash $Environment
  $ctx.Context.VaultName = Get-VaultName $Environment
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

function Get-TemplateParameter {
  <#
  .SYNOPSIS
  Evaluate a parameter file template and return the
  file's content.

  .PARAMETER Context
  The deployment context.
  #>

  param (
    [Parameter(Mandatory)]
    [DeploymentContext] $Context
  )

  # Lookup the parameters file
  $parameterFile = Get-DeploymentFile `
    -Context ${private:Context}.Context.Name `
    -Path "Templates/$(${private:Context}.TemplateName)" `
    -Extension 'Parameters.json'

  # Evaluate the parameter file and return it
  $arguments = @{
    # Variables to expose
    ContextVariables = @{
      context  = $Context.Context
      manifest = Get-Manifest
    }

    # Functions to copy from current scope to template scope
    ContextFunctions = @('Get-Property')

    # Scope
    Context          = {
      function Get-Context {
        <#
        .SYNOPSIS Return (part of the) context (as JSON)
        #>
        param(
          [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
          [string[]] $Filters
        )
        Get-Property $Context -Filters $Filters -ThrowOnMiss | ConvertTo-Json
      }

      function Get-Manifest {
        <#
        .SYNOPSIS Return (part of the) manifest (as JSON)
        #>
        param(
          [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
          [string[]] $Filters
        )
        Get-Property $manifest -Filters $Filters -ThrowOnMiss | ConvertTo-Json
      }
    }
  }
  Get-Content -Path $parameterFile -Raw -Encoding 'UTF8' | Merge-Template @arguments
}

function New-TemplateDeployment {
  <#
  .SYNOPSIS
  Start a new template deployment.

  .PARAMETER Context
  The deployment context.

  .PARAMETER Parameters
  Parameters to pass to the template deployment.
  #>

  param (
    [Parameter(Mandatory)]
    [DeploymentContext] $Context,
    [hashtable] $Parameters = @{}
  )

  # Create resource group if needed
  New-ResourceGroup -Name $Context.ResourceGroup -Location $Context.Location

  # Lookup the template file
  $templateFile = Get-DeploymentFile `
    -Context $Context.Context.Name `
    -Path "Templates/$($Context.TemplateName)" `
    -Extension 'Template.json'

  # Create the deployment
  New-AzResourceGroupDeployment `
    -Name ((New-Guid).Guid) `
    -ResourceGroupName $Context.ResourceGroup `
    -TemplateFile $templateFile `
    -TemplateParameterObject $Parameters `
    -Mode 'Incremental' `
    -Force `
    -Verbose
}
