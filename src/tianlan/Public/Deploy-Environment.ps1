function Deploy-Environment {
  <#
  .SYNOPSIS
  Deploy an environment.

  .PARAMETER Name
  The environment name.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  # Login
  Connect-Azure -Environment $Name

  # Deploy the resources
  $context = Get-DeploymentContext -Environment $Name
  New-TemplateDeployment -Context $context

  # Import the certificates
  $spNames = Get-Manifest 'environments', $Name, 'servicePrincipals' -DefaultValue @() -Properties -ThrowOnMiss
  foreach ($spName in @($spNames)) {
    $spDef = Get-Manifest 'environments', $Name, 'servicePrincipals', $spName
    Import-Certificate `
      -VaultName $context.Context.VaultName `
      -Name $spDef.certificate.name `
      -Thumbprint $spDef.certificate.thumbprint
  }
}