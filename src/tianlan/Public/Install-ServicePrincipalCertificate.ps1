function Install-ServicePrincipalCertificate {
  <#
  .SYNOPSIS
  Install (in the local certstore) a service principal's certifiate.

  .DESCRIPTION
  Install (in the local certstore) a service principal's certifiate.

  Note: this scripts runs in interactive mode. Current user must have permission on the environment's vault.

  .PARAMETER Environment
  The environment name.

  .PARAMETER ServicePrincipal
  The service principal name. Default to admin.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Environment,
    [string] $ServicePrincipal = 'admin'
  )

  # Lookup definitions
  $envDef = Get-Manifest 'environments', $Environment
  if (!$envDef) {
    throw 'Environment does not exist'
  }
  $spDef = Get-Manifest 'environments', $Environment, 'servicePrincipals', $ServicePrincipal
  if (!$spDef) {
    throw 'Service principal does not exist'
  }

  # Login
  Invoke-Step 'Authenticating' {
    Connect-Azure -SubscriptionId $envDef.subscriptionId
  }

  # Export the certificate
  Invoke-Step 'Installing environment certificate' {
    Export-Certificate `
      -VaultName (Get-VaultName -Environment $Environment) `
      -Name $spDef.certificate.name `
      -Thumbprint $spDef.certificate.thumbprint
  }
}