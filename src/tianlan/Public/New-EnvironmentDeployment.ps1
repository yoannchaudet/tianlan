function New-EnvironmentDeployment {
  <#
  .SYNOPSIS
  Create an environment deployment.

  .DESCRIPTION
  Create an environment deployment.

  WIP

  .PARAMETER Name
  The environment name.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  # Login
  Connect-Azure -Environment $Name

  # Start the deployment
  $context = Get-DeploymentContext -Environment $Name
  New-TemplateDeployment -Context $context

  # Import the admin certificate
  $servicePrincipal = Get-Manifest 'servicePrincipals' "$($Name).admin" -ThrowOnMiss
  $certificate = Get-Certificate -Thumbprint $servicePrincipal.certificateThumbprint
  Invoke-Retry {
    Import-AzKeyVaultCertificate `
      -VaultName $context.Context.VaultName `
      -Name 'Admin-Certificate' `
      -CertificateCollection $certificate
  }
}