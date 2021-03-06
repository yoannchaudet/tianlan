# Tiānlán

Tiānlán (天蓝) which translates to azure (the color) in Chinese is a simple deployment system for the cloud provider of
the [same name](https://azure.microsoft.com/en-us/).

## Continous Integration

[![Build status](https://dev.azure.com/yoannchaudet/tianlan/_apis/build/status/tianlan)](https://dev.azure.com/yoannchaudet/tianlan/_build/latest?definitionId=1)

## Requirements

The project works on Windows, Linux and macOS.

Required runtime: [PowerShell Core (6.x)](https://github.com/PowerShell/PowerShell).

Until the project is published to the gallery, install dependencies this way:

- Install Pester first (for unit tests)
  ```pwsh
  Install-Module -Name Pester -MinimumVersion 4.6.0 -Scope CurrentUser
  ```
- Install other dependencies with the build script
  ```pwsh
  ./build.ps1
  ```

## Getting started: run the shell

Tiānlán is packaged as a PowerShell module which exposes a single function: `Invoke-Tianlan`.

The function starts a dedicated PowerShell Core shell (either on your host or in a container) which exposes a different
PowerShell module with all the functionalities of Tiānlán. This indirection is aimed at keeping things clean and tidy.

In order to start the shell (from the root of the repository):

```pwsh
# Start the shell in a container:
./build.ps1 Import; Invoke-Tianlan -Mode Docker

# To start the shell on the host directly:
./build.ps1 Import; Invoke-Tianlan
```

## Run unit tests

From the root of the repository:

```pwsh
./build.ps1 Test
```

Run unit tests for a single file:

```pwsh
./build.ps1 Test -Parameters @{ Path = 'src/tianlan/Private/Manifest.Tests.ps1' }
```

The `Parameters` hashtable is passed directly to [Invoke-Pester](https://github.com/pester/Pester/wiki/Invoke-Pester)
(the entry point to the test framework we use).

## Getting started: provision an environment

Ideally, create a new git repository and start the shell from it (or use the `-DeploymentPath` parameter to point at its
location on disk).

Create the environment first, this step shall run once only:

```pwsh
# You will be prompted for the other parameters
New-Environment -Name dev
```

If you are planning to deploy an [AKS cluster](https://docs.microsoft.com/en-us/azure/aks/), also create an extra
service principal:

```pwsh
New-ServicePrincipal -Environment dev -Name aksAdmin
```

You should see a new `Manifest.json` file at the root of your repository/deployment path. This is keeping track of what
you will be deploying and where. It is a good idea to version control this file.

Provision your environment with:

```pwsh
Deploy-Environment -Name dev
```

This script is idempotent (you can run it any time you make a change to the environment). This will provision a Key
Vault for the environment and upload the self-signed certificates that were generated for your service principals.

Make sure you run `New-Environment`, `New-ServicePrincipal` and `Deploy-Environment` from the same machine. Once the
certificates have been uploaded, this limitation goes away.

