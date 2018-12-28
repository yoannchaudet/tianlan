function Get-DefaultManifest {
  <#
  .SYNOPSIS
  Return a default manifest.
  #>

  # Return a default (empty) manifest file
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
  #>

  param (
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null
  )

  # Get the manifest file path
  $manifestFile = Join-DeploymentPath 'Manifest.json' -SkipValidation

  # Parse the manifest
  if (Test-Path $manifestFile) {
    $manifest = Get-Content -Raw -Path $manifestFile -Encoding 'UTF8' | ConvertFrom-Json
  }

  # Return a default (empty) manifest
  else {
    $manifest = Get-DefaultManifest
  }

  # Select requested part of the manifest (if needed)
  if ($Filters) {
    foreach ($segment in $Filters) {
      if ($manifest -and $manifest.psobject.Properties[$segment] -and $manifest.$segment -ne $null) {
        $manifest = $manifest.$segment
      }
      else {
        $manifest = $DefaultValue
        break
      }
    }
  }

  # Return the manifest
  return $manifest
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
    [Parameter(Mandatory = $true)]
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