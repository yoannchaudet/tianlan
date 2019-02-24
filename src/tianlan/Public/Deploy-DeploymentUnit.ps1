function Deploy-Stamp {
  <#
  .SYNOPSIS
  Deploy a stamp.

  .PARAMETER Environment
  The environment.

  .PARAMETER Name
  The stamp name.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [Parameter(Mandatory)]
    [string] $Name
  )

  # Login
  Invoke-Step 'Authenticating' {
    Connect-Azure -Environment $Environment
  }

  # Deploy the resources
  Invoke-Step 'Deploying resources' {
    $context = Get-StampContext -Environment $Environment -Stamp $Name
    New-TemplateDeployment -Context $context
  }
}