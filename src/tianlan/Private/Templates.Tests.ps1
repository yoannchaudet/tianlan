InModuleScope Tianlan {
  Describe 'Merge-Template' {
    It 'Supports special characters' {
      "Hello my friend's, do you like ```$?" `
      | Merge-Template `
      | Should -Be "Hello my friend's, do you like `$?"
    }

    It 'Supports variable expansion' {
      "Hello `$friend." `
      | Merge-Template -Context { $friend = 'my friend' }  `
      | Should -Be 'Hello my friend.'
    }

    It 'Supports function expansion' {
      "Hello `$(friend)." `
      | Merge-Template -Context { function friend { 'my friend' }}  `
      | Should -Be 'Hello my friend.'
    }

    It 'Throws when a variable or function is not defined' {
      { "`$testVariable" | Merge-Template } | Should -Throw
      { "`$(testVariable)" | Merge-Template } | Should -Throw
    }

    It 'Supports rich PowerShell syntax' {
      "Hello `$(`$friends -Join ', ')!" `
      | Merge-Template -Context { $friends = @('Qing', 'Yoann') } `
      | Should -Be "Hello Qing, Yoann!"
    }
  }
}