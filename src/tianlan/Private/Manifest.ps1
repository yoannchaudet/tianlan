function Get-NewManifest {
  <#
  .SYNOPSIS
  Return a new manifest.
  #>

  # Return a new (empty) manifest file
  '{
     "environments": {}
  }' | ConvertFrom-Json
}

function Get-Manifest {
  <#
  .SYNOPSIS
  Return the current Manifest.json file.

  .PARAMETER Filters
  Optional string array of properties to follow in the Manifest.
  When provided, returns the matching property if possible.

  .PARAMETER DefaultValue
  When Filters is provided, set the value to return in case the filter
  fails. Default to null.

  .PARAMETER ThrowOnMiss
  Throw an exception if the Filters fail.

  .PARAMETER Properties
  Return the list of properties of the object instead of the object.
  #>

  param (
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null,
    [switch] $ThrowOnMiss,
    [switch] $Properties
  )

  # Get the manifest file path
  $manifestFile = Join-DeploymentPath 'Manifest.json'

  # Parse the manifest or get a default one
  if ($manifestFile) {
    $manifest = Get-Content -Raw -Path $manifestFile -Encoding 'UTF8' | ConvertFrom-Json
  }
  else {
    $manifest = Get-NewManifest
  }

  # Return the filtered manifest
  Get-Property `
    -Object $manifest `
    -Filters $Filters `
    -DefaultValue $DefaultValue `
    -ThrowOnMiss:$ThrowOnMiss `
    -Properties:$Properties
}

function Get-ServicePrincipalDefinition {
  <#
  .SYNOPSIS
  Return a service principal definition.

  .PARAMETER ServicePrincipal
  The service principal object (returned by New-AdServicePrincipal).

  .PARAMETER CertificateName
  The name to give the certificate.
  #>

  param (
    [pscustomobject] $ServicePrincipal,
    [string] $CertificateName
  )

  return [pscustomobject] @{
    id            = $ServicePrincipal.ServicePrincipal.Id
    applicationId = $ServicePrincipal.ServicePrincipal.ApplicationId
    tenantId      = (Get-AzContext).Tenant.Id
    certificate   = @{
      thumbprint = $ServicePrincipal.Certificate.Thumbprint
      name       = $CertificateName
    }
  }
}

function Get-EnvironmentDefinition {
  <#
  .SYNOPSIS
  Return an environment definition.

  .PARAMETER Name
  Environment name.

  .PARAMETER SubscriptionId
  Environment subscription id.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Location,
    [Parameter(Mandatory)]
    [string] $SubscriptionId
  )

  return [pscustomobject] @{
    location          = $Location
    subscriptionId    = $SubscriptionId
  }
}

function Set-Manifest {
  <#
  .SYNOPSIS
  Update the content of the Manifest.json file.

  .PARAMETER Content
  The content to set. Note: no validation is executed.

  Supported types: string, psobject, hashtable.
  #>

  param (
    [Parameter(Mandatory)]
    [object] $Content
  )

  # Get path of the manifest file
  $manifestPath = Join-DeploymentPath 'Manifest.json'
  if (!$manifestPath) {
    $manifestPath = Join-Path (Get-DeploymentPath) 'Manifest.json'
  }

  # Parse string as json (does syntax validation and reformatting when written in the file)
  if ($Content -is [string]) {
    $Content = $Content | ConvertFrom-Json
  }

  # Output the file
  if ($Content -is [pscustomobject] -or $Content -is [hashtable]) {
    $Content | ConvertTo-Json -Depth 100 | Out-File -FilePath $manifestPath -Encoding 'UTF8'
  }
  else {
    throw 'Unsupported content type'
  }
}