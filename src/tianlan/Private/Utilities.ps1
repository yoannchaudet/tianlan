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
    [Parameter(Mandatory = $True)]
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
    } catch {
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