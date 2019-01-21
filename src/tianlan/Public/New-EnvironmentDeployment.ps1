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
  $certificateDefinition = Get-Manifest 'environments', $Name, 'servicePrincipals', 'admin', 'certificate' -ThrowOnMiss
  $certificate = Get-Certificate -Thumbprint $certificateDefinition.thumbprint
  Invoke-Retry {
    Import-AzKeyVaultCertificate `
      -VaultName $context.Context.VaultName `
      -Name $certificateDefinition.name `
      -CertificateCollection $certificate
  }
}