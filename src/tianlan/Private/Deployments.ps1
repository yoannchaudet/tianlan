#
# Types
#

class Context {
  # Context name (either environment or stamp)
  [string] $Name
  # Environment
  [string] $Environment
  # Stamp
  [string] $Stamp
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
  Return the name of the key vault for a given entity (environment/stamp).

  .PARAMETER Environment
  The environment name.

  .PARAMETER Stamp
  The stamp (if applicable).
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [string] $Stamp
  )

  if ($Stamp) {
    $hash = Get-Hash "${Environment}_${Stamp}"
  }
  else {
    $hash = Get-Hash $Environment
  }
  return "vault$hash"
}

function Get-EnvironmentContext {
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
  $environmentDef = Get-Manifest 'environments', $Environment -ThrowOnMiss

  # Build the context object and return it
  $ctx = [DeploymentContext]::new()
  $ctx.TemplateName = '$KeyVault'
  $ctx.ResourceGroup = $Environment
  $ctx.Location = $environmentDef.location
  $ctx.Context = [Context]::new()
  $ctx.Context.Name = $Environment
  $ctx.Context.Environment = $Environment
  $ctx.Context.Hash = Get-Hash $ctx.ResourceGroup
  $ctx.Context.VaultName = Get-VaultName -Environment $Environment
  return $ctx
}

function Get-StampContext() {
  <#
  .SYNOPSIS
  Return a deployment context.

  .PARAMETER Environment
  The environment.

  .PARAMETER Stamp
  The stamp for which to return a context.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [Parameter(Mandatory)]
    [string] $Stamp
  )

  # Get stamp definition
  $duDef = Get-Manifest 'environments', $Environment, 'stamps', $Stamp -ThrowOnMiss

  # Build the context object and return it
  $ctx = [DeploymentContext]::new()
  $ctx.TemplateName = '$KeyVault'
  $ctx.ResourceGroup = "${Environment}_${Stamp}"
  $ctx.Location = $duDef.location
  $ctx.Context = [Context]::new()
  $ctx.Context.Name = $Stamp
  $ctx.Context.Environment = $Environment
  $ctx.Context.Stamp = $Stamp
  $ctx.Context.Hash = Get-Hash $ctx.ResourceGroup
  $ctx.Context.VaultName = Get-VaultName -Environment $Environment -Stamp $Stamp
  return $ctx
}

function Get-DeploymentFile() {
  <#
  .SYNOPSIS
  Return the path to a deployment file.

  .DESCRIPTION
  Return the path to a deployment file.

  Look in order at (most specific to least specific):
  - path.stamp.environment.extension
  - path.environment.extension
  - path.extension (default file)

  Returns null if no files can be found.

  .PARAMETER Environment
  The environment name.

  .PARAMETER Stamp
  The stamp name.

  .PARAMETER Path
  The path to the file to look for.

  .PARAMETER Extension
  The file extension (without a starting dot).
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [string] $Stamp,
    [Parameter(Mandatory)]
    [string] $Path,
    [Parameter(Mandatory)]
    [string] $Extension
  )

  # Paths to try (in order)
  $paths = @()
  if ($Stamp) {
    $paths += "${Path}.${Stamp}.${Environment}.${Extension}"
  }
  $paths += "${Path}.${Environment}.${Extension}"
  $paths += "${Path}.${Extension}"

  # Return the first path that works
  foreach ($candidatePath in $paths) {
    $resolvedPath = Join-DeploymentPath $candidatePath
    if ($resolvedPath) {
      return $resolvedPath
    }
  }
}

function Get-TemplateParameter {
  <#
  .SYNOPSIS
  Evaluate a parameter file template and return the
  file's content (if any).

  .PARAMETER Context
  The deployment context.
  #>

  param (
    [Parameter(Mandatory)]
    [DeploymentContext] $Context
  )

  # Lookup the parameters file
  $parameterFile = Get-DeploymentFile `
    -Environment $Context.Context.Environment `
    -Stamp $Context.Context.Stamp `
    -Path "Templates/$($Context.TemplateName)" `
    -Extension 'Parameters.json'
  if (!$parameterFile) {
    return
  }

  # Evaluate the parameter file and return it
  $arguments = @{
    # Variables to expose
    ContextVariables = @{
      context  = $Context.Context
      manifest = Get-Manifest
    }

    # Functions to copy from current scope to template scope
    ContextFunctions = @('Get-Property', 'Get-JsonProperty')

    # Scope
    Context          = {
      function Get-Context {
        <#
        .SYNOPSIS Return (part of the) context (as JSON)
        #>
        param(
          [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
          [string[]] $Filters,
          [switch] $Raw
        )
        Get-JsonProperty $context -Filters $Filters -ThrowOnMiss -Raw:$Raw
      }

      function Get-Manifest {
        <#
        .SYNOPSIS Return (part of the) manifest (as JSON)
        #>
        param(
          [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
          [string[]] $Filters,
          [switch] $Raw
        )
        Get-JsonProperty $manifest -Filters $Filters -ThrowOnMiss -Raw:$Raw
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
  #>

  param (
    [Parameter(Mandatory)]
    [DeploymentContext] $Context
  )

  # Create resource group if needed
  New-ResourceGroup -Name $Context.ResourceGroup -Location $Context.Location

  # Lookup the template file
  $templateFile = Get-DeploymentFile `
    -Environment $Context.Context.Environment `
    -Stamp $Context.Context.Stamp `
    -Path "Templates/$($Context.TemplateName)" `
    -Extension 'Template.json'

  # Evaluate the parameter file (if any)
  $parameterFileContent = Get-TemplateParameter -Context $Context

  # Create the deployment
  Use-TemporaryFile {
    param ($parameterFile, $context, $templateFile, $parameterFileContent)

    # Prepare deployment parameters
    $params = @{
      Name              = (New-Guid).Guid
      ResourceGroupName = $context.ResourceGroup
      TemplateFile      = $templateFile
      Mode              = 'Incremental'
      Force             = $true
      Verbose           = $true
    }

    # Persist the parameter file on disk if any and add it to the list of deployment
    # parameters
    if ($parameterFileContent) {
      $parameterFileContent | Out-File -FilePath $parameterFile -Encoding 'UTF8'
      $params['TemplateParameterFile'] = $parameterFile
    }

    # Run the deployment
    New-AzResourceGroupDeployment @params
  } -ScriptBlockArguments @($Context, $templateFile, $parameterFileContent)
}
