FROM mcr.microsoft.com/powershell

# Change shell
SHELL ["pwsh", "-Command"]

# Install Az
RUN Install-Module -Name 'Az' -Force

# Set working directory (where volumes are mounted)
WORKDIR /tianlan

# Set entrypoint
ENTRYPOINT ["pwsh", "-NoExit", "-Command", ". /tianlan/module/Tianlan.profile.ps1"]
