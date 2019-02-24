function New-Environment {
  <#
  .SYNOPSIS
  Declare and initalize a new environment.

  .DESCRIPTION
  Declare and initialize a new environment.

  Note: this scripts runs in interactive mode. Current user must have Owner permission
  on the subscription and admin permission on the tenant.

  .PARAMETER Name
  The environment name.

  .PARAMETER SubscriptionId
  The subscription where to create the environment.

  .PARAMETER Location
  The location where to provision the environment.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $SubscriptionId,
    [Parameter(Mandatory)]
    [string] $Location
  )

  # Make sure the environment is not declared already
  if (Get-Manifest 'environments', $Name) {
    throw 'Environment already exists'
  }

  # Login
  Invoke-Step 'Authenticating' {
    Connect-Azure -SubscriptionId $SubscriptionId
  }

  # Create a new service principal
  $sp = Invoke-Step 'Creating admin service principal' {
    New-AdServicePrincipal -DisplayName "admin ($Name)" -Admin
  }

  # Assign a role on the service principal
  # Note, we need a retry here because of https://github.com/Azure/azure-powershell/issues/2286
  Invoke-Step 'Assigning admin service principal Owner role on the subscription' {
    Invoke-Retry {
      New-AzRoleAssignment `
        -RoleDefinitionName 'Owner' `
        -ApplicationId ($sp.ServicePrincipal.ApplicationId) `
        -Scope "/subscriptions/$SubscriptionId"
    } -RetryDelay { 10 } -MaxRetries 5
  }

  # Create an admin group and add the service principal to it
  $group = Invoke-Step 'Creating admin AD group' {
    New-AzAdGroup -DisplayName "Admin Group ($Name)" -MailNickname "admin_$Name" | Tee-Object -Variable 'group'
    Add-AzADGroupMember -MemberObjectId $sp.ServicePrincipal.Id -TargetGroupObjectId $group.Id
  }

  # Update the manifest
  Invoke-Step 'Updating manifest' {
    # Get current manifest
    $manifest = Get-Manifest

    # Declare environment
    $envDef = Get-EnvironmentDefinition -Location $Location -SubscriptionId $SubscriptionId -AdminGroupId $group.Id
    $manifest = $manifest | Add-Property -Properties 'environments', $Name -Value $envDef

    # Declare service principal
    $certificateName = Get-CertificateName 'admin'
    $spDef = Get-ServicePrincipalDefinition -ServicePrincipal $sp -CertificateName $certificateName
    $manifest = $manifest | Add-Property -Properties 'environments', $Name, 'servicePrincipals', 'admin' -Value $spDef

    # Save manifest
    Set-Manifest $manifest
  }
}
