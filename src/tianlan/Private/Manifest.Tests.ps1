InModuleScope Tianlan {
  Describe 'Join-DeploymentPath' {
    BeforeEach {
      # Set deployment path to a temporary folder and create it
      $global:DeploymentPath = (New-TemporaryFile).FullName
      Remove-Item -Path $global:DeploymentPath -Force
      New-Item -Path $global:DeploymentPath -ItemType 'Directory'

      # Add some files there too
      'hello here' | Out-File -FilePath (Join-Path $global:DeploymentPath 'here.txt')
      New-Item -Path (Join-Path $global:DeploymentPath 'f') -ItemType 'Directory'
      'hello there' | Out-File -FilePath (Join-Path $global:DeploymentPath 'f/there.txt')
    }

    AfterEach {
      # Clean the temporary folder
      Remove-Item -Path $global:DeploymentPath -Recurse -Force
    }

    It "Join paths with validation" {
      Join-DeploymentPath 'here.txt' | Should -Be (Join-Path $global:DeploymentPath 'here.txt')
      Join-DeploymentPath 'f/there.txt' | Should -Be (Join-Path $global:DeploymentPath 'f/there.txt')
      { Join-DeploymentPath 'there.txt' } | Should -Throw "Deployment path not found: $(Join-Path $global:DeploymentPath 'there.txt')"
    }

    It "Join paths without validation" {
      Join-DeploymentPath 'hello' -SkipValidation | Should -Be (Join-Path $global:DeploymentPath 'hello')
      Join-DeploymentPath 'hello/my/friend' -SkipValidation | Should -Be (Join-Path $global:DeploymentPath 'hello/my/friend')
    }
  }

  Describe 'Get-DefaultManifest' {
    It 'Returns a value' {
      Get-DefaultManifest | Should -Not -Be $null
      Get-DefaultManifest | Should -BeOfType PSCustomObject
    }
  }

  Describe 'Get-Manifest' {
    It 'Always returns a value' {
      Get-Manifest | Should -BeLike (Get-DefaultManifest)
    }

    It 'Returns actual provided Manifest.json file' {
      # Set deployment path to a temporary folder and create it
      $global:DeploymentPath = (New-TemporaryFile).FullName
      Remove-Item -Path $global:DeploymentPath -Force
      New-Item -Path $global:DeploymentPath -ItemType 'Directory'

      # Create a Manifest.json file
      $manifest = '{
        "servicePrincipals": {
          "test": {}
        }
       }'
      $manifest | Out-File -FilePath (Join-Path $global:DeploymentPath 'Manifest.json')

      # Make sure we can access the test object
      (Get-Manifest).servicePrincipals.test | Should -Not -Be $null
    }
  }
}