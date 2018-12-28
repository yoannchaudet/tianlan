InModuleScope Tianlan {
  Describe 'Invoke-Retry' {
    It 'Pass-throughs on success (with parameters)' {
      function Invoke-Me { param ([int] $I) }
      Mock 'Invoke-Me' { 42 }
      Invoke-Retry { param ([int] $I) Invoke-Me $I } -Parameters @{ I = 42 } | Should -Be 42
      Assert-MockCalled Invoke-Me -Times 1 -Exactly
    }

    It 'Pass-throughs on partial success' {
      function Invoke-Me2 { param ($i) }
      $script:calls = 0
      Mock 'Invoke-Me2' {
        $script:calls++
        if ($script:calls -lt 2) { throw 'x' } else { 'success' }
      }
      Invoke-Retry { Invoke-Me2 } | Should -Be 'success'
      Assert-MockCalled Invoke-Me2 -Times 2 -Exactly
    }

    It 'Does not retry more than X times' {
      function Invoke-Me3 {}
      Mock 'Invoke-Me3' { throw 'x' }
      { Invoke-Retry { Invoke-Me3 } -MaxRetries 6 -RetryDelay { 0 } } | Should -Throw 'x'
      Assert-MockCalled Invoke-Me3 -Times 7 -Exactly
    }

    It 'Waits when needed' {
      function Invoke-Me4 {}
      Mock 'Invoke-Me4' { throw 'x' }
      Mock 'Start-Sleep' { $Seconds | Should -Be 1 }
      { Invoke-Retry { Invoke-Me4 } -MaxRetries 2 -RetryDelay { param ($i) ($i-1) } } | Should -Throw 'x'
      Assert-MockCalled Invoke-Me4 -Times 3 -Exactly
      Assert-MockCalled Start-Sleep -Times 1 -Exactly
    }
  }
}