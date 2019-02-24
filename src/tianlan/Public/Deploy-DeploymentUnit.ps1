function Deploy-DeploymentUnit {
  <#
  .SYNOPSIS
  Deploy a deployment unit..

  .PARAMETER Environment
  The environment.

  .PARAMETER Name
  The deployment unit name.
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
    $context = Get-DeploymentUnitContext -Environment $Environment -DeploymentUnit $Name
    New-TemplateDeployment -Context $context
  }
}