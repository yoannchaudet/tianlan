function Invoke-Retry {
  <#
  .SYNOPSIS
  Invoke a scriptblock and retry upon exceptions.

  .DESCRIPTION
  Invoke a scriptblock and retry upon exceptions.

  .PARAMETER ScriptBlock
  The block to execute.

  .PARAMETER Parameters
  Parameters to pass to the block.

  .PARAMETER MaxRetries
  Maximum number of retries to attempt.

  .PARAMETER RetryDelay
  A function to pace down retries: retry tentative (1-indexed) -> wait time in seconds.
  #>

  param (
    [Parameter(Mandatory)]
    [scriptblock] $ScriptBlock,
    [hashtable] $Parameters = @{},
    [int] $MaxRetries = 2,
    [scriptblock] $RetryDelay = { param ($i) Get-Random -Maximum $i }
  )

  # Iterate
  for ($tentative = 1; $tentative -le ($MaxRetries + 1); $tentative += 1) {
    try {
      & $ScriptBlock @Parameters
      break
    }
    catch {
      # Exit
      if ($tentative -gt $MaxRetries) { throw }

      # Pace-down next retry
      $delayInSeconds = & $RetryDelay $tentative
      Write-Warning "Error [tentative $tentative of $($MaxRetries+1)], [delay: $delayInSeconds second(s)]:`n$($_ | Format-List | Out-String)"
      if ($delayInSeconds -gt 0) {
        Start-Sleep -Seconds $delayInSeconds
      }
    }
  }
}

function Get-Hash {
  <#
  .SYNOPSIS
  Return a short hash for a given string.

  .PARAMETER Value
  The value to hash.

  .PARAMETER Length
  The length of the hash.
  #>
  param(
    [Parameter(Mandatory)]
    [string] $Value,
    [ValidateRange(1, 40)]
    [int] $Length = 10
  )

  # Hash the string using SHA-1 (produces up to 40 bytes/characters)
  $encoding = [System.Text.Encoding]::UTF8
  $sha1 = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider
  $hash = $sha1.ComputeHash($encoding.GetBytes($Value))
  $hashString = ($hash | ForEach-Object { $_.ToString('x2') }) -Join ''
  $hashString.Substring(0, $Length)
}

function Add-Property {
  <#
  .SYNOPSIS
  Add a property to an object and return the object.

  .PARAMETER Object
  The manifest object.

  .PARAMETER Property
  The property name.

  .PARAMETER Value
  The value to set.
  #>

  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [pscustomobject] $InputObject,
    [Parameter(Mandatory, Position = 0)]
    [string[]] $Properties,
    [Parameter(Mandatory)]
    [AllowNull()]
    [pscustomobject] $Value
  )

  function Add-PropertyRecursively {
    param (
      [Parameter(Mandatory, ValueFromPipeline)]
      [pscustomobject] $InputObject,
      [Parameter(Mandatory, Position = 0)]
      [string[]] $Properties,
      [Parameter(Mandatory)]
      [AllowNull()]
      [pscustomobject] $Value
    )

    # Create the first property that is requested if not available on the object
    $property = $Properties[0]
    $propertyValue = $InputObject | Select-Object -ExpandProperty $property -ErrorAction 'SilentlyContinue'
    if (!$propertyValue) {
      $InputObject | Add-Member -Type 'NoteProperty' -Name $property -Value ([pscustomobject] @{}) -Force
    }

    # If leaf property is reached, set the value
    if ($Properties.Length -eq 1) {
      $InputObject.$property = $Value
    }

    # Recursively drill down
    else {
      Add-PropertyRecursively -InputObject $InputObject.$property -Properties ($Properties | Select-Object -Skip 1) -Value $Value
    }
  }

  # Add the property then return the top-level object
  Add-PropertyRecursively -InputObject $InputObject -Properties $Properties -Value $Value
  return $InputObject
}

function Get-Property {
  <#
  .SYNOPSIS
  Return a given property in an object.

  .PARAMETER Object
  The object to filter.

  .PARAMETER Filters
  Optional string array of properties to follow in the object.
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
    [Parameter(Position = 0)]
    [pscustomobject] $Object,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null,
    [switch] $ThrowOnMiss,
    [switch] $Properties
  )

  # Select requested part of the object (if needed)
  $filteredObject = $Object
  if ($Filters) {
    foreach ($segment in $Filters) {
      $segmentValue = $filteredObject | Select-Object -ExpandProperty $segment -ErrorAction 'SilentlyContinue'
      if ($null -ne $segmentValue) {
        $filteredObject = $segmentValue
      }
      else {
        if ($ThrowOnMiss) {
          throw "Unable to locate $($Filters -Join '.')"
        }
        $filteredObject = $DefaultValue
        break
      }
    }
  }

  # Handle properties switch
  if ($Properties -and $filteredObject) {
    $filteredObject = ([pscustomobject] $filteredObject).psobject.properties.name
  }

  return $filteredObject
}

function Get-JsonProperty {
  <#
  .SYNOPSIS
  Same as Get-Property but returns JSON by default unless the Raw switch is set.

  .PARAMETER Raw
  Switch to return raw value instead of JSON.
  #>

  param (
    [Parameter(Position = 0)]
    [pscustomobject] $Object,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null,
    [switch] $ThrowOnMiss,
    [switch] $Raw
  )

  # Get property
  $property = Get-Property -Object $Object -Filters $Filters -DefaultValue $DefaultValue -ThrowOnMiss:$ThrowOnMiss
  if (!$Raw) {
    $property = $property | ConvertTo-Json -Depth 100
  }
  return $property
}

function Use-TemporaryFile {
  <#
  .SYNOPSIS
  Execute a script block in the context of a temporary file.

  .DESCRIPTION
  Execute a script block in the context of a temporary file.

  The temporary file is removed upon completion of the script block.

  .PARAMETER ScriptBlock
  The script block to execute. It is passed a single parameter: the temporary file path.

  .PARAMETER ScriptBlockArguments
  Optional array of arguments to pass to the script block. May be used not to leak
  variables in the script block's scope.

  .PARAMETER Extension
  Optional extension to give the temporary file (including .).

  .PARAMETER DontRemoveFile
  Switch indicating if the file should be removed right away or not.
  #>
  param (
    [Parameter(Mandatory)]
    [scriptblock] $ScriptBlock,
    [array] $ScriptBlockArguments = @(),
    [string] $Extension = ""
  )

  # Create a temp file
  # Note on that: https://github.com/PowerShell/PowerShell/issues/4216
  $private:file = Join-Path ([System.IO.Path]::GetTempPath()) "$(New-Guid)${private:Extension}"
  try {
    # Call the script block
    & $ScriptBlock $private:file @ScriptBlockArguments
  }
  finally {
    # Remove the file
    Remove-Item -Path $private:file -Force -ErrorAction 'SilentlyContinue'
  }
}

function Get-CertificateName {
  <#
  .SYNOPSIS
  Return a certificate name given a name.

  .PARAMETER Name
  The name to transform.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  # Sanitize the string
  $Name = $Name -replace '[^a-zA-Z]', ''
  # Upper case the first character
  return "$("$($Name[0])".ToUpper())$($Name.Substring(1, $Name.Length - 1))-Certificate"

}