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