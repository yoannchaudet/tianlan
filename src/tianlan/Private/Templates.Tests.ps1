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
        | Merge-Template -Context { function friend { 'my friend' }} `
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

    It 'Supports context variables' {
      "`$thing1 and `$thing2" `
        | Merge-Template -ContextVariables @{thing1 = 'Thing1'; thing2 = 'Thing2'} `
        | Should -Be "Thing1 and Thing2"
    }

    It 'Does not expose internal context variable' {
      { "`$localContext" | Merge-Template } | Should -Throw
    }

    It 'Loads variables before scriptblock' {
      "`$(Get-Manifest)" `
        | Merge-Template -ContextVariables @{ template = 'template' } -Context { function Get-Manifest { $template }} `
        | Should -Be "template"
    }

    It 'Can inject function manually' {
      function Get-X {
        param ([string] $Param)
        "Get-X called with Param=$Param"
      }
      "`$(Get-X 'hello')" `
        | Merge-Template -ContextVariables @{ xDefinition = [scriptblock](${function:Get-X}) } -Context { Set-Item -Path function:Get-X -Value $xDefinition } `
        | Should -Be "Get-X called with Param=hello"
    }

    It 'Can inject function automatically' {
      function Get-Y {
        param ([string] $Param)
        "Get-Y called with Param=$Param"
      }
      "`$(Get-Y 'hello')" `
        | Merge-Template -ContextFunctions @('Get-Y') `
        | Should -Be "Get-Y called with Param=hello"
    }

    It 'Can do everything at once' {
      function Call-One {
        ${variable.one}
      }

      function Call-Two {
        "$(Call-One) two"
      }

      "`$(Call-Three)" `
        | Merge-Template `
        -ContextVariables @{ 'variable.one' = 'one' } `
        -ContextFunctions @('Call-One', 'Call-Two') `
        -Context {
        function Call-Three {
          "$(Call-Two) three!"
        }
      } `
        | Should -Be "one two three!"
    }
  }
}