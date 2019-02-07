FROM mcr.microsoft.com/powershell

# Install docker
RUN apt-get update -qq && apt-get install -qqy \
  apt-transport-https \
  ca-certificates \
  curl \
  lxc \
  iptables \
  && curl -sSL https://get.docker.com/ | sh

# Change shell
SHELL ["pwsh", "-Command"]

# Install dependencies
RUN Install-Module -Name 'Az'                     -MinimumVersion 1.2.1 -Force
RUN Install-Module -Name 'SelfSignedCertificate'  -MinimumVersion 0.0.4 -Force
RUN Install-Module -Name 'Pester'                 -MinimumVersion 4.6.0 -Force

# Set entrypoint
ENTRYPOINT ["pwsh"]
