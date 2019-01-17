function Merge-Template {
  <#
  .SYNOPSIS
  Merge a template with a provided context.

  .DESCRIPTION
  Merge a template with a provided context.

  Execution is safe and happens in a dedicated pwsh session. Because of the
  execution context, access to global functions or variables is not available.

  Instead a context can be injected in the form of (in this specific order):
  - variables (to be copied in the context)
  - functions (to be copied in the context)
  - a script block (that can only reference injected variables or functions)

  .PARAMETER Template
  The template to evaluate.

  .PARAMETER ContextVariables
  Optional set of variables to inject for the template evaluation.

  .PARAMETER ContextFunctions
  Optional list of functions to inject for the template evaluation.

  .PARAMETER Context
  Optional script block to inject for the template evaluation.
  #>

  param (
    [parameter(ValueFromPipeline, Mandatory)]
    [string] $Template,
    [hashtable] $ContextVariables = @{},
    [array] $ContextFunctions = @(),
    [scriptblock] $Context = {}
  )

  # Define a local context
  $localContext = @{}
  foreach ($variable in $ContextVariables.Keys) {
    $localContext["variable.$variable"] = $ContextVariables[$variable]
  }
  foreach ($function in $ContextFunctions) {
    $localContext["function.$function"] = (Get-Command -Name $function).Definition
  }

  # Prepare the script to run
  $script = @"
# Set strict mode
Set-StrictMode -version 'Latest';
# Clear system variables
Get-Variable | Remove-Variable -Force -ErrorAction 'SilentlyContinue';
# Stop on errors and surface the error message
`$ErrorActionPreference = 'Stop';
`$ErrorView = 'NormalView';
# Initalize context
`$localContext = [System.Management.Automation.PSSerializer]::Deserialize(
  `$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(
  '$([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([System.Management.Automation.PSSerializer]::Serialize($localContext))))'
))));
foreach (`$key in `$localContext.Keys) {
  if (`$key.StartsWith('variable.')) {
    Set-Variable -Name `$key.Substring('variable.'.Length) -Value `$localContext[`$key]
  }
};
foreach (`$key in `$localContext.Keys) {
  if (`$key.StartsWith('function.')) {
    Set-Item -Path "function:`$(`$key.Substring('function.'.Length))" -Value `$localContext[`$key]
  }
};
Remove-Variable -Name 'localContext';
# Load context
$Context;
# Evaluate template (base64 is used to protect the string)
`$ExecutionContext.InvokeCommand.ExpandString(
  `$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(
  '$([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Template)))'
  ))));
"@

  # Run the script
  Use-TemporaryFile {
    param($scriptPath)
    # Write the temp script on disk
    $script | Out-File -FilePath $scriptPath -Encoding 'UTF8'

    # Evaluate the template
    $pwsh = (Get-Command 'pwsh').Source
    & $pwsh -NoProfile -File $scriptPath 2>&1
  }
}