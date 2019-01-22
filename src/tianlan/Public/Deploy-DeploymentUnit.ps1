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
  Connect-Azure -Environment $Environment

  # Deploy the resources
  $context = Get-DeploymentUnitContext -Environment $Environment -DeploymentUnit $Name
  New-TemplateDeployment -Context $context
}