function Merge-Template {
  <#
  .SYNOPSIS
  Merge a template with a provided context.

  .DESCRIPTION
  Merge a template with a provided context.

  Execution is safe and happens in a dedicated pwsh session. The
  context can contain both functions and variables.

  .PARAMETER Template
  The template to evaluate.

  .PARAMETER Context
  The context to inject for the template evaluation.
  #>

  param (
    [parameter(ValueFromPipeline, Mandatory)]
    [string] $Template,
    [scriptblock] $Context = {}
  )

  # Prepare the command to run
  $pwsh = (Get-Command 'pwsh').Source
  $command = @"
# Set strict mode
Set-StrictMode -version 'Latest';
# Clear system variables
Get-Variable | Remove-Variable -Force -ErrorAction 'SilentlyContinue';
# Stop on errors and surface the error message
`$ErrorActionPreference = 'Stop';
`$ErrorView = 'NormalView';
# Load context
$Context;
# Evaluate template (base64 is used to protect the string)
`$ExecutionContext.InvokeCommand.ExpandString(
  `$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(
  '$([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Template)))'
  ))));
"@

  # Evaluate the template
  & $pwsh -NoProfile -Command $command 2>&1
}