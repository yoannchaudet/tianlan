function Connect-Azure {
  <#
  .SYNOPSIS
  Connect to Azure if needed.

  .DESCRIPTION
  Connect to Azure if needed and return the requested subscription identifier.

  .PARAMETER SubscriptionId
  The subscription identifier.
  #>

  param (
    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId
  )

  try {
    & {
      # Flag indicating if we need to connect
      $requiresConnect = $true

      # Get the context
      $context = Get-AzContext

      # Already connected
      if ($context -and $context.Account.Type -eq 'User' -and $context.Subscription.Id -eq $SubscriptionId) {
        return
      }

      # If the current context is an account one, try to switch the subscription
      if ($context -and $context.Account.Type -eq 'User' -and (Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction 'SilentlyContinue')) {
        $context = Set-AzContext -Subscription $SubscriptionId
        $requiresConnect = $context.Subscription.Id -ne $SubscriptionId
      }

      # Connect if needed
      if ($requiresConnect) {
        $context = Connect-AzAccount -Subscription $SubscriptionId
        if ($context.Subscription.Id -ne $SubscriptionId) {
          throw 'Unable to connect for requested subscription'
        }
      }
    }

    # Update shell's authentication context (so it's displayed in the prompt)
    $global:TIANLIN_AUTHCONTEXT = $SubscriptionId

    # Return the subscription
    return $SubscriptionId
  }
  catch {
    # Clear shell's authentication context
    $global:TIANLIN_AUTHCONTEXT = $null

    # Re-throw exception
    throw
  }
}