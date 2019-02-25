function Connect-Azure {
  <#
  .SYNOPSIS
  Connect to Azure if needed.

  .DESCRIPTION
  Connect to Azure if needed and return the requested subscription identifier.

  .PARAMETER SubscriptionId
  The subscription identifier. When provided do an interactive login.

  .PARAMETER Environment
  The environment to connect to. When provided do a non-interactive login.
  #>

  param (
    [Parameter(Mandatory, ParameterSetName = 'Interactive')]
    [string] $SubscriptionId,
    [Parameter(Mandatory, ParameterSetName = 'NonInteractive')]
    [string] $Environment
  )

  # Get available contexts
  $contexts = Get-AzContext -ListAvailable

  # Try to select appropriate context
  if ($PsCmdlet.ParameterSetName -eq 'Interactive') {
    $context = $contexts | Where-Object {
      $_.Account.Type -eq 'User' `
        -and $_.Subscription -and $_.Subscription.Id -eq $SubscriptionId
    }
  }
  else {
    $SubscriptionId = (Get-Manifest 'environments' $Environment -ThrowOnMiss).subscriptionId
    $servicePrincipal = Get-Manifest 'environments' $Environment 'servicePrincipals' 'admin' -ThrowOnMiss
    $context = $contexts | Where-Object {
      $_.Account.Type -eq 'ServicePrincipal' `
        -and $_.Account.Id -eq $servicePrincipal.applicationId `
        -and $_.Subscription -and $_.Subscription.Id -eq $SubscriptionId
    }
  }

  # Set context or connect
  if ($context) {
    Select-AzContext -InputObject @($context)[0] | Out-Null
  }
  else {
    if ($PsCmdlet.ParameterSetName -eq 'Interactive') {
      Connect-AzAccount -Subscription $SubscriptionId | Out-Null
    }
    else {
      Connect-AzAccount `
        -CertificateThumbprint $servicePrincipal.certificate.thumbprint `
        -ApplicationId $servicePrincipal.applicationId `
        -Tenant $servicePrincipal.tenantId `
        -ServicePrincipal | Out-Null
      if (!(Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction 'SilentlyContinue')) {
        throw 'Service principal does not have access to requested subscription'
      }
      Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
    }
  }

  # Return current context
  Get-AzContext
}

function New-RandomPassword {
  <#
  .SYNOPSIS
  Generate and return a random password.

  .PARAMETER Length
  The password length (default to 16).

  .PARAMETER AsSecureString
  Return the password as a secure string.
  #>

  param (
    [int] $Length = 16,
    [switch] $AsSecureString
  )

  # Build an ASCII range
  $asciiRange = $null
  for ($c = 48; $c –le 122; $c++) {
    $asciiRange += , [char][byte]$c
  }

  # Build a password
  $password = ''
  for ($i = 0; $i -lt $Length; $i++) {
    $password += ($asciiRange | Get-Random)
  }

  # Return the password
  if ($AsSecureString) {
    $password = ConvertTo-SecureString $password -AsPlainText -Force
  }
  return $password
}

function New-LocalCertificate {
  <#
  .SYNOPSIS
  Generate a new self-signed certificate.

  .DESCRIPTION
  Generate a new self-signed certificate, save it on disk (for xplat)
  and add it to the current user store (via code for xplat again).

  Based on https://gist.github.com/cormacpayne/6f15ce9bdaf6edc1d7b11c52bb924c44.

  Return a reference to the certificate.

  .PARAMETER CommonName
  The certificate's common name.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $CommonName
  )

  Use-TemporaryFile {
    param ($certPath)

    # Generate the certificate
    $certPassword = New-RandomPassword -AsSecureString
    $cert = New-SelfSignedCertificate `
      -OutCertPath $certPath `
      -CommonName $CommonName `
      -CertificateFormat 'Pfx' `
      -KeyUsage 'DigitalSignature', 'KeyEncipherment' `
      -Passphrase $certPassword `
      -EnhancedKeyUsage 'ServerAuthentication', 'ClientAuthentication' `
      -ForCertificateAuthority `
      -KeyLength 4096 `
      -NotAfter ([System.DateTime]::Now.AddYears(2))

    # Add the certificate to the certstore
    $storeName = [System.Security.Cryptography.X509Certificates.StoreName]
    $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]
    $openFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]
    $x509Certificate2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName::My, $storeLocation::CurrentUser)
    $store.Open($openFlags::ReadWrite)
    $store.Add($x509Certificate2::New($certPath, $certPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
    $store.Close()

    # Return the certificate
    return $cert
  } -Extension '.pfx'
}

function Get-LocalCertificate {
  <#
  .SYNOPSIS
  Return a certificate (from the certstore) by thumbprint.

  .PARAMETER Thumbprint
  The certificate's thumbprint.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Thumbprint
  )

  # Try to read the certificate from the certstore
  $storeName = [System.Security.Cryptography.X509Certificates.StoreName]
  $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]
  $openFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]
  $findType = [System.Security.Cryptography.X509Certificates.X509FindType]
  $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName::My, $storeLocation::CurrentUser)
  $store.Open($openFlags::ReadOnly)
  $certificates = $store.Certificates.Find($findType::FindByThumbprint, $Thumbprint, $false)
  $store.Close()

  # Only handle the case where exactly one certificate matches
  if ($certificates.Count -eq 1) {
    return $certificates[0]
  }
}

function Remove-LocalCertificate {
  <#
  .SYNOPSIS
  Remove a certificate (from the certstore) by thumbprint.

  Return a boolean indicating if the certificate was removed.

  .PARAMETER Thumbprint
  The certificate's thumbprint.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $Thumbprint
  )

  # Get the certificate
  $certificate = Get-LocalCertificate $Thumbprint
  if (!$certificate) {
    return $false
  }

  # Update the certstore
  $storeName = [System.Security.Cryptography.X509Certificates.StoreName]
  $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]
  $openFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]
  $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName::My, $storeLocation::CurrentUser)
  $store.Open($openFlags::ReadWrite)
  $store.Remove($certificate)
  $store.Close()
  return $true
}

function New-AdServicePrincipal {
  <#
  .SYNOPSIS
  Create a new service principal.

  .DESCRIPTIOn
  Create a new service principal (along with a self-sign certificate) and return a reference object
  with the following properties:
  - Certificate
  - ServicePrincipal

  .PARAMETER DisplayName
  The display name.

  .PARAMETER Admin
  Switch to control wether to give the service principal admin permission
  on the current tenant.

  When set to true, private APIs are used to grant permissions. The service principal
  can then be used to provision other service principals (and manage them).

  Note: The current Azure context must have permissions to grant the service principal permissions.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $DisplayName,
    [switch] $Admin
  )

  # Create a new certificate
  $certificate = New-LocalCertificate -CommonName $DisplayName

  # Create an application first
  $application = Invoke-Retry {
    New-AzADApplication `
      -DisplayName $DisplayName `
      -IdentifierUris "https://identity.tianlan.io/$((New-Guid).Guid)" `
      -CertValue ([System.Convert]::ToBase64String($certificate.GetRawCertData())) `
      -StartDate $certificate.NotBefore `
      -EndDate $certificate.NotAfter
  }

  # Then create a service principal
  $servicePrincipal = Invoke-Retry {
    New-AzADServicePrincipal `
      -ApplicationId $application.ApplicationId
  }

  # Make the service principal a tenant admin
  if ($Admin) {
    # Get an access token for talking to the Azure Portal
    $context = Get-AzContext
    $azureSession = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]
    $token = $azureSession::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")

    # Grant permissions
    Write-Debug 'Granting service principal tenant admin permissions...'
    $response = Invoke-Retry {
      $payload = @{
        objectId               = $application.ObjectId
        requiredResourceAccess = @(
          @{
            resourceAppId  = "00000003-0000-0000-c000-000000000000" # Microsoft Graph application
            resourceAccess = @(
              @{
                id   = "19dbc75e-c2e2-444c-a770-ec69d8559fc7" # Directory.ReadWrite.All (Read and write directory data)
                type = "Role"
              },
              @{
                "id"   = "0e263e50-5827-48a4-b97c-d940288653c7" # Directory.AccessAsUser.All (Access directory as the signed in user)
                "type" = "Scope"
              }
            )
          },
          @{
            resourceAppId  = "00000002-0000-0000-c000-000000000000" # Windows Azure Active Directory
            resourceAccess = @(
              @{
                id   = "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7" # Application.ReadWrite.OwnedBy (Manage apps that this app creates or owns)
                type = "Role"
              }
            )
          })
      }
      Invoke-WebRequest `
        -Uri "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$($application.ObjectId)" `
        -Method "PUT" `
        -Headers @{"Authorization" = "Bearer $($token.AccessToken)"; "x-ms-client-request-id" = (New-Guid).Guid} `
        -ContentType "application/json" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 100)))
    }
    if ($response.StatusCode -ne 200) {
      throw "Error while granting service principal admin permissions`n$($response | Format-List | Out-String)"
    }

    # Grant admin consent
    Write-Debug 'Granting service principal admin consent...'
    $response = Invoke-Retry {
      Invoke-WebRequest `
        -Uri "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$($servicePrincipal.ApplicationId)/Consent?onBehalfOfAll=true" `
        -Method "POST" `
        -Headers @{"Authorization" = "Bearer $($token.AccessToken)"; "x-ms-client-request-id" = (New-Guid).Guid}
    }
    if ($response.StatusCode -ne 204) {
      throw "Error while granting service principal admin consent`n$($response | Format-List | Out-String)"
    }
  }

  # Return a reference object
  return @{
    Certificate      = $certificate
    ServicePrincipal = $servicePrincipal
  }
}

function Import-Certificate {
  <#
  .SYNOPSIS
  Import a certificate to Key Vault (if needed).

  .PARAMETER VaultName
  The name of the vault.

  .PARAMETER Name
  The name of the certificate.

  .PARAMETER Thumbprint
  The certificate thumbprint.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $VaultName,
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $Thumbprint
  )

  # Get the uploaded certificate if any
  $uploadedCertificate = Invoke-Retry {
    Get-AzKeyVaultCertificate -VaultName $VaultName -Name $Name -ErrorAction 'SilentlyContinue'
  }

  # Upload the certificate if needed
  if ($uploadedCertificate -and $uploadedCertificate.Certificate.Thumbprint -eq $Thumbprint) {
    Write-Host "Certificate $Name already in key vault ($VaultName)"
  }
  else {
    Invoke-Step "Importing certificate $Name into key vault ($VaultName)" {
      $certificate = Get-LocalCertificate -Thumbprint $Thumbprint
      Invoke-Retry {
        Import-AzKeyVaultCertificate `
          -VaultName $VaultName `
          -Name $Name `
          -CertificateCollection $certificate
      }
    }
  }
}

function Export-Certificate {
  <#
  .SYNOPSIS
  Export a certificate out of Key Vault (if needed) and place it in the local certstore.

  .PARAMETER VaultName
  The name of the vault.

  .PARAMETER Name
  The name of the certificate.

  .PARAMETER Thumbprint
  The certificate thumbprint.
  #>

  param (
    [Parameter(Mandatory)]
    [string] $VaultName,
    [Parameter(Mandatory)]
    [string] $Name,
    [Parameter(Mandatory)]
    [string] $Thumbprint
  )

  # If the certificate is already in the certstore, ignore
  if (Get-LocalCertificate -Thumbprint $Thumbprint) {
    Write-Host "Certificate $Name already in local certstore"
    return
  }

  # Export the certificate out of keyvault
  Invoke-Step "Exporting certificate $Name from key vault ($VaultName)" {
    # Read certificate's matching secret
    $secret = Invoke-Retry {
      Get-AzKeyVaultSecret -VaultName $VaultName -Name $Name
    }

    # Validate content type (should not hurt)
    if ($secret.ContentType -ne 'application/x-pkcs12') {
      throw 'Unexpected content type'
    }

    # Add the certificate to the certstore
    $storeName = [System.Security.Cryptography.X509Certificates.StoreName]
    $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]
    $openFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]
    $x509Certificate2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName::My, $storeLocation::CurrentUser)
    $store.Open($openFlags::ReadWrite)
    $store.Add($x509Certificate2::New([System.Convert]::FromBase64String($secret.SecretValueText), '', [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
    $store.Close()
  }
}