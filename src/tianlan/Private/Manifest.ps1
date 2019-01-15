function Get-NewManifest {
  <#
  .SYNOPSIS
  Return a new manifest.
  #>

  # Return a new (empty) manifest file
  '{
    "servicePrincipals": {},
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
  #>

  param (
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null,
    [switch] $ThrowOnMiss
  )

  # Get the manifest file path
  $manifestFile = Join-DeploymentPath 'Manifest.json' -SkipValidation

  # Parse the manifest or get a default one
  if (Test-Path $manifestFile) {
    $manifest = Get-Content -Raw -Path $manifestFile -Encoding 'UTF8' | ConvertFrom-Json
  }
  else {
    $manifest = Get-NewManifest
  }

  # Return the filtered manifest
  Get-Property -Object $manifest -Filters $Filters -DefaultValue $DefaultValue -ThrowOnMiss:$ThrowOnMiss
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
  $manifestPath = Join-DeploymentPath 'Manifest.json' -SkipValidation

  # Parse string as json (does syntax validation and reformatting when written in the file)
  if ($Content -is [string]) {
    $Content = $Content | ConvertFrom-Json
  }

  # Output the file
  if ($Content -is [psobject] -or $Content -is [hashtable]) {
    $Content | ConvertTo-Json | Out-File -FilePath $manifestPath -Encoding 'UTF8'
  }
  else {
    throw 'Unsupported content type'
  }
}