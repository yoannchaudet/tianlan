# Tiānlán

Tiānlán (天蓝) which translates to azure (the color) in Chinese is a simple
deployment system for the cloud provider of the [same name](https://azure.microsoft.com/en-us/).

## Requirements

The project works on Windows, Linux and macOS.

Required runtime: [PowerShell Core (6.x)](https://github.com/PowerShell/PowerShell).

For dependencies, two solutions:

1. Install Docker and stop there (this is the preferred route if you are not familiar with PowerShell)

2. Install the dependencies one by one (this is preferred if you are contributing to the project):

   - Az 1.0.0
   - WIP: Add link, manage this differently

## Getting started

Tiānlán is packaged as a PowerShell module which exposes a single function: `Invoke-Tianlan`.

The function starts a dedicated PowerShell Core shell (either in your host or in a container) which
exposes a different PowerShell module with all the functionalities of Tiānlán. This indirection is
aimed at keeping things clean and tidy.

In order to start the shell (from the root of the repository):

``` PS
# Start the shell in a container:
Import-Module ./src/TianlanShell.psd1; Invoke-Tianlan -Mode Docker

# To start the shell on the host directly:
Import-Module ./src/TianlanShell.psd1 ; Invoke-Tianlan
```

