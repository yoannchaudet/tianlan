# Tiānlán

Tiānlán (天蓝) which translates to azure (the color) in Chinese is a simple
deployment system for the cloud provider of the [same name](https://azure.microsoft.com/en-us/).

## Requirements

The project works on Windows, Linux and macOS.

Required runtime: [PowerShell Core (6.x)](https://github.com/PowerShell/PowerShell).

For dependencies, two solutions:

1. Install Docker and stop there (this is the preferred route if you are not familiar with PowerShell)

2. Install the dependencies one by one (this is preferred if you are contributing to the project):

   - Pester 4.4.3+ (for tests only)
   - Az 1.0.0 (for runtime)
   - SelfSignedCertificate 0.0.4 (for runtime)
   - WIP: Add link, manage this differently

## Getting started: run the shell

Tiānlán is packaged as a PowerShell module which exposes a single function: `Invoke-Tianlan`.

The function starts a dedicated PowerShell Core shell (either in your host or in a container) which
exposes a different PowerShell module with all the functionalities of Tiānlán. This indirection is
aimed at keeping things clean and tidy.

In order to start the shell (from the root of the repository):

``` PS
# Start the shell in a container:
./build.ps1 Import; Invoke-Tianlan -Mode Docker

# To start the shell on the host directly:
./build.ps1 Import; Invoke-Tianlan
```

## Run unit tests

From the root of the repository:

``` PS
./build.ps1 Test
```

Run unit tests for a single file:

``` PS
./build.ps1 Test -Parameters @{ Path = 'src/tianlan/Private/Manifest.Tests.ps1' }
```

The `Parameters` hashtable is passed directly to [Invoke-Pester](https://github.com/pester/Pester/wiki/Invoke-Pester) (the entry point to the test framework we use).