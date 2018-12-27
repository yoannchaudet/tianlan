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

function New-Certificate {
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
    [Parameter(Mandatory = $true)]
    [string] $CommonName
  )

  # Generate the certificate
  # Note on the temp path: https://github.com/PowerShell/PowerShell/issues/4216
  $certPath = Join-Path ([System.IO.Path]::GetTempPath()) "$((New-Guid).Guid).pfx"
  $certPassword = New-RandomPassword -AsSecureString
  try {
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
    $store.Add($x509Certificate2::New($certPath, $certPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable))
    $store.Close()
  }
  finally {
    Remove-Item -Path $certPath -Force -ErrorAction 'SilentlyContinue'
  }

  # Return a reference object
  return $cert
}

function Get-Certificate {
  <#
  .SYNOPSIS
  Return a certificate (from the certstore) by thumbprint.

  .PARAMETER Thumbprint
  The certificate's thumbprint.
  #>

  param (
    [Parameter(Mandatory = $true)]
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