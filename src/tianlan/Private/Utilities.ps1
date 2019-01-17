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

function Get-Property {
  <#
  .SYNOPSIS
  Return a given property in an object.

  .PARAMETER Filters
  Optional string array of properties to follow in the object.
  When provided, returns the matching property if possible.

  .PARAMETER DefaultValue
  When Filters is provided, set the value to return in case the filter
  fails. Default to null.

  .PARAMETER ThrowOnMiss
  Throw an exception if the Filters fail.
  #>

  param (
    [Parameter(Position=0)]
    [pscustomobject] $Object,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]] $Filters,
    [object] $DefaultValue = $null,
    [switch] $ThrowOnMiss
  )

  # Select requested part of the object (if needed)
  $filteredObject = $Object
  if ($Filters) {
    foreach ($segment in $Filters) {
      $segmentValue = $filteredObject | Select-Object -ExpandProperty $segment -ErrorAction 'SilentlyContinue'
      if ($segmentValue -ne $null) {
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

  # Return the object
  return $filteredObject
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