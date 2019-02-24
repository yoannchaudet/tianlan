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
  Invoke-Step 'Authenticating' {
    Connect-Azure -Environment $Name
  }

  # Deploy the resources
  $context = Get-EnvironmentContext -Environment $Name
  Invoke-Step 'Deploying resources' {
    New-TemplateDeployment -Context $context
  }

  # Import the certificates
  Invoke-Step "Importing service principals' certificates" {
    $spNames = Get-Manifest 'environments', $Name, 'servicePrincipals' -DefaultValue @() -Properties -ThrowOnMiss
    foreach ($spName in @($spNames)) {
      $spDef = Get-Manifest 'environments', $Name, 'servicePrincipals', $spName
      Import-Certificate `
        -VaultName $context.Context.VaultName `
        -Name $spDef.certificate.name `
        -Thumbprint $spDef.certificate.thumbprint
    }
  }
}