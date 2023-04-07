using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function Run-Step([string] $Description, [ScriptBlock]$script)
{
  Write-Host  -NoNewline "Loading " $Description.PadRight(20)
  & $script
  Write-Host "`u{2705}" # checkmark emoji
}

[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

Write-Host "Loading PowerShell $($PSVersionTable.PSVersion)..." -ForegroundColor 3
# if $HUYNH_CONFIG_DIR not found echo error
if (-not (Test-Path env:HUYNH_CONFIG_DIR)) {
    Write-Error 'Please set $HUYNH_CONFIG_DIR env variable to your config directory'
}

if ($host.Name -eq 'ConsoleHost') {
    Run-Step "PS-Readline" { Import-Module PSReadLine }
}
# Import-Module -Name Terminal-Icons
function setIcon { Import-Module -Name Terminal-Icons }
set-alias icon setIcon

Run-Step "oh-my-posh" {
    oh-my-posh --init --shell pwsh --config $env:HUYNH_CONFIG_DIR/terminal/terminal-utils/oh-my-posh/tokyonight_stormv2.omp.json | Invoke-Expression
}

function setAliasAndKeyBinding {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }

    # PowerShell parameter completion shim for the dotnet CLI
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }

    # ---
    # This is an example profile for PSReadLine.
    #
    # This is roughly what I use so there is some emphasis on emacs bindings,
    # but most of these bindings make sense in Windows mode as well.

    # Searching for commands with up/down arrow is really handy.  The
    # option "moves to end" is useful if you want the cursor at the end
    # of the line while cycling through history like it does w/o searching,
    # without that option, the cursor will remain at the position it was
    # when you used up arrow, which can be useful if you forget the exact
    # string you started the search on.
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # This key handler shows the entire or filtered history using Out-GridView. The
    # typed text is used as the substring pattern for filtering. A selected command
    # is inserted to the command line without invoking. Multiple command selection
    # is supported, e.g. selected by Ctrl + Click.
    Set-PSReadLineKeyHandler -Key F7 `
        -BriefDescription History `
        -LongDescription 'Show command history' `
        -ScriptBlock {
        echo 'test'
        $pattern = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
        if ($pattern) {
            $pattern = [regex]::Escape($pattern)
        }

        $history = [System.Collections.ArrayList]@(
            $last = ''
            $lines = ''
            foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath)) {
                if ($line.EndsWith('`')) {
                    $line = $line.Substring(0, $line.Length - 1)
                    $lines = if ($lines) {
                        "$lines`n$line"
                    }
                    else {
                        $line
                    }
                    continue
                }

                if ($lines) {
                    $line = "$lines`n$line"
                    $lines = ''
                }

                if (($line -cne $last) -and (!$pattern -or ($line -match $pattern))) {
                    $last = $line
                    $line
                }
            }
        )
        $history.Reverse()

        $command = $history | Out-GridView -Title History -PassThru
        if ($command) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
        }
    }


    # CaptureScreen is good for blog posts or email showing a transaction
    # of what you did when asking for help or demonstrating a technique.
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d,Ctrl+c' -Function CaptureScreen

    # The built-in word movement uses character delimiters, but token based word
    # movement is also very useful - these are the bindings you'd use if you
    # prefer the token based movements bound to the normal emacs word movement
    # key bindings.
    Set-PSReadLineKeyHandler -Key Alt+d -Function ShellKillWord
    Set-PSReadLineKeyHandler -Key Alt+Backspace -Function ShellBackwardKillWord
    Set-PSReadLineKeyHandler -Key Alt+b -Function ShellBackwardWord
    Set-PSReadLineKeyHandler -Key Alt+f -Function ShellForwardWord
    Set-PSReadLineKeyHandler -Key Alt+B -Function SelectShellBackwardWord
    Set-PSReadLineKeyHandler -Key Alt+F -Function SelectShellForwardWord

    #region Smart Insert/Delete

    # The next four key handlers are designed to make entering matched quotes
    # parens, and braces a nicer experience.  I'd like to include functions
    # in the module that do this, but this implementation still isn't as smart
    # as ReSharper, so I'm just providing it as a sample.

    Set-PSReadLineKeyHandler -Key '"', "'" `
        -BriefDescription SmartInsertQuote `
        -LongDescription "Insert paired quotes if not already on a quote" `
        -ScriptBlock {
        param($key, $arg)

        $quote = $key.KeyChar

        $selectionStart = $null
        $selectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        # If text is selected, just quote it without any smarts
        if ($selectionStart -ne -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
            return
        }

        $ast = $null
        $tokens = $null
        $parseErrors = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

        function FindToken {
            param($tokens, $cursor)

            foreach ($token in $tokens) {
                if ($cursor -lt $token.Extent.StartOffset) { continue }
                if ($cursor -lt $token.Extent.EndOffset) {
                    $result = $token
                    $token = $token -as [StringExpandableToken]
                    if ($token) {
                        $nested = FindToken $token.NestedTokens $cursor
                        if ($nested) { $result = $nested }
                    }

                    return $result
                }
            }
            return $null
        }

        $token = FindToken $tokens $cursor

        # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
        if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
            # If we're at the start of the string, assume we're inserting a new string
            if ($token.Extent.StartOffset -eq $cursor) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                return
            }

            # If we're at the end of the string, move over the closing quote if present.
            if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                return
            }
        }

        if ($null -eq $token -or
            $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
            if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1) {
                # Odd number of quotes before the cursor, insert a single quote
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
            }
            else {
                # Insert matching quotes, move cursor to be in between the quotes
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            }
            return
        }

        # If cursor is at the start of a token, enclose it in quotes.
        if ($token.Extent.StartOffset -eq $cursor) {
            if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or
                $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
                $end = $token.Extent.EndOffset
                $len = $end - $cursor
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
                return
            }
        }

        # We failed to be smart, so just insert a single quote
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
    }

    Set-PSReadLineKeyHandler -Key '(', '{', '[' `
        -BriefDescription InsertPairedBraces `
        -LongDescription "Insert matching braces" `
        -ScriptBlock {
        param($key, $arg)

        $closeChar = switch ($key.KeyChar) {
            <#case#> '(' { [char]')'; break }
            <#case#> '{' { [char]'}'; break }
            <#case#> '[' { [char]']'; break }
        }

        $selectionStart = $null
        $selectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($selectionStart -ne -1) {
            # Text is selected, wrap it in brackets
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        }
        else {
            # No text is selected, insert a pair
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
    }

    Set-PSReadLineKeyHandler -Key ')', ']', '}' `
        -BriefDescription SmartCloseBraces `
        -LongDescription "Insert closing brace or skip" `
        -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($line[$cursor] -eq $key.KeyChar) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
        }
    }

    Set-PSReadLineKeyHandler -Key Backspace `
        -BriefDescription SmartBackspace `
        -LongDescription "Delete previous character or matching quotes/parens/braces" `
        -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($cursor -gt 0) {
            $toMatch = $null
            if ($cursor -lt $line.Length) {
                switch ($line[$cursor]) {
                    <#case#> '"' { $toMatch = '"'; break }
                    <#case#> "'" { $toMatch = "'"; break }
                    <#case#> ')' { $toMatch = '('; break }
                    <#case#> ']' { $toMatch = '['; break }
                    <#case#> '}' { $toMatch = '{'; break }
                }
            }

            if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
            }
            else {
                [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
            }
        }
    }

    #endregion Smart Insert/Delete

    # Sometimes you enter a command but realize you forgot to do something else first.
    # This binding will let you save that command in the history so you can recall it,
    # but it doesn't actually execute.  It also clears the line with RevertLine so the
    # undo stack is reset - though redo will still reconstruct the command line.
    Set-PSReadLineKeyHandler -Key Alt+w `
        -BriefDescription SaveInHistory `
        -LongDescription "Save current line in history but do not execute" `
        -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    }

    # Insert text from the clipboard as a here string
    Set-PSReadLineKeyHandler -Key Ctrl+V `
        -BriefDescription PasteAsHereString `
        -LongDescription "Paste the clipboard text as a here string" `
        -ScriptBlock {
        param($key, $arg)

        Add-Type -Assembly PresentationCore
        if ([System.Windows.Clipboard]::ContainsText()) {
            # Get clipboard text - remove trailing spaces, convert \r\n to \n, and remove the final \n.
            $text = ([System.Windows.Clipboard]::GetText() -replace "\p{Zs}*`r?`n", "`n").TrimEnd()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
        }
    }

    # Sometimes you want to get a property of invoke a member on what you've entered so far
    # but you need parens to do that.  This binding will help by putting parens around the current selection,
    # or if nothing is selected, the whole line.
    Set-PSReadLineKeyHandler -Key 'Alt+(' `
        -BriefDescription ParenthesizeSelection `
        -LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
        -ScriptBlock {
        param($key, $arg)

        $selectionStart = $null
        $selectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($selectionStart -ne -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
            [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
        }
    }

    # Each time you press Alt+', this key handler will change the token
    # under or before the cursor.  It will cycle through single quotes, double quotes, or
    # no quotes each time it is invoked.
    Set-PSReadLineKeyHandler -Key "Alt+'" `
        -BriefDescription ToggleQuoteArgument `
        -LongDescription "Toggle quotes on the argument under the cursor" `
        -ScriptBlock {
        param($key, $arg)

        $ast = $null
        $tokens = $null
        $errors = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

        $tokenToChange = $null
        foreach ($token in $tokens) {
            $extent = $token.Extent
            if ($extent.StartOffset -le $cursor -and $extent.EndOffset -ge $cursor) {
                $tokenToChange = $token

                # If the cursor is at the end (it's really 1 past the end) of the previous token,
                # we only want to change the previous token if there is no token under the cursor
                if ($extent.EndOffset -eq $cursor -and $foreach.MoveNext()) {
                    $nextToken = $foreach.Current
                    if ($nextToken.Extent.StartOffset -eq $cursor) {
                        $tokenToChange = $nextToken
                    }
                }
                break
            }
        }

        if ($tokenToChange -ne $null) {
            $extent = $tokenToChange.Extent
            $tokenText = $extent.Text
            if ($tokenText[0] -eq '"' -and $tokenText[-1] -eq '"') {
                # Switch to no quotes
                $replacement = $tokenText.Substring(1, $tokenText.Length - 2)
            }
            elseif ($tokenText[0] -eq "'" -and $tokenText[-1] -eq "'") {
                # Switch to double quotes
                $replacement = '"' + $tokenText.Substring(1, $tokenText.Length - 2) + '"'
            }
            else {
                # Add single quotes
                $replacement = "'" + $tokenText + "'"
            }

            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                $extent.StartOffset,
                $tokenText.Length,
                $replacement)
        }
    }

    # This example will replace any aliases on the command line with the resolved commands.
    Set-PSReadLineKeyHandler -Key "Alt+%" `
        -BriefDescription ExpandAliases `
        -LongDescription "Replace all aliases with the full command" `
        -ScriptBlock {
        param($key, $arg)

        $ast = $null
        $tokens = $null
        $errors = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

        $startAdjustment = 0
        foreach ($token in $tokens) {
            if ($token.TokenFlags -band [TokenFlags]::CommandName) {
                $alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
                if ($alias -ne $null) {
                    $resolvedCommand = $alias.ResolvedCommandName
                    if ($resolvedCommand -ne $null) {
                        $extent = $token.Extent
                        $length = $extent.EndOffset - $extent.StartOffset
                        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                            $extent.StartOffset + $startAdjustment,
                            $length,
                            $resolvedCommand)

                        # Our copy of the tokens won't have been updated, so we need to
                        # adjust by the difference in length
                        $startAdjustment += ($resolvedCommand.Length - $length)
                    }
                }
            }
        }
    }

    # F1 for help on the command line - naturally
    Set-PSReadLineKeyHandler -Key F1 `
        -BriefDescription CommandHelp `
        -LongDescription "Open the help window for the current command" `
        -ScriptBlock {
        param($key, $arg)

        $ast = $null
        $tokens = $null
        $errors = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

        $commandAst = $ast.FindAll( {
                $node = $args[0]
                $node -is [CommandAst] -and
                $node.Extent.StartOffset -le $cursor -and
                $node.Extent.EndOffset -ge $cursor
            }, $true) | Select-Object -Last 1

        if ($commandAst -ne $null) {
            $commandName = $commandAst.GetCommandName()
            if ($commandName -ne $null) {
                $command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
                if ($command -is [AliasInfo]) {
                    $commandName = $command.ResolvedCommandName
                }

                if ($commandName -ne $null) {
                    Get-Help $commandName -ShowWindow
                }
            }
        }
    }


    #
    # Ctrl+Shift+j then type a key to mark the current directory.
    # Ctrj+j then the same key will change back to that directory without
    # needing to type cd and won't change the command line.

    #
    $global:PSReadLineMarks = @{}

    Set-PSReadLineKeyHandler -Key Ctrl+J `
        -BriefDescription MarkDirectory `
        -LongDescription "Mark the current directory" `
        -ScriptBlock {
        param($key, $arg)

        $key = [Console]::ReadKey($true)
        $global:PSReadLineMarks[$key.KeyChar] = $pwd
    }

    Set-PSReadLineKeyHandler -Key Ctrl+j `
        -BriefDescription JumpDirectory `
        -LongDescription "Goto the marked directory" `
        -ScriptBlock {
        param($key, $arg)

        $key = [Console]::ReadKey()
        $dir = $global:PSReadLineMarks[$key.KeyChar]
        if ($dir) {
            cd $dir
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        }
    }

    Set-PSReadLineKeyHandler -Key Alt+j `
        -BriefDescription ShowDirectoryMarks `
        -LongDescription "Show the currently marked directories" `
        -ScriptBlock {
        param($key, $arg)

        $global:PSReadLineMarks.GetEnumerator() | % {
            [PSCustomObject]@{Key = $_.Key; Dir = $_.Value } } |
        Format-Table -AutoSize | Out-Host

        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }

    # Auto correct 'git cmt' to 'git commit'
    Set-PSReadLineOption -CommandValidationHandler {
        param([CommandAst]$CommandAst)

        switch ($CommandAst.GetCommandName()) {
            'git' {
                $gitCmd = $CommandAst.CommandElements[1].Extent
                switch ($gitCmd.Text) {
                    'cmt' {
                        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                            $gitCmd.StartOffset, $gitCmd.EndOffset - $gitCmd.StartOffset, 'commit')
                    }
                }
            }
        }
    }

    # `ForwardChar` accepts the entire suggestion text when the cursor is at the end of the line.
    # This custom binding makes `RightArrow` behave similarly - accepting the next word instead of the entire suggestion text.
    Set-PSReadLineKeyHandler -Key RightArrow `
        -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
        -LongDescription "Move cursor one character to the right in the current editing line and accept the next word in suggestion when it's at the end of current editing line" `
        -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($cursor -lt $line.Length) {
            [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord($key, $arg)
        }
    }

    # Cycle through arguments on current line and select the text. This makes it easier to quickly change the argument if re-running a previously run command from the history
    # or if using a psreadline predictor. You can also use a digit argument to specify which argument you want to select, i.e. Alt+1, Alt+a selects the first argument
    # on the command line.
    Set-PSReadLineKeyHandler -Key Alt+a `
        -BriefDescription SelectCommandArguments `
        -LongDescription "Set current selection to next command argument in the command line. Use of digit argument selects argument by position" `
        -ScriptBlock {
        param($key, $arg)

        $ast = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$null, [ref]$null, [ref]$cursor)

        $asts = $ast.FindAll( {
                $args[0] -is [System.Management.Automation.Language.ExpressionAst] -and
                $args[0].Parent -is [System.Management.Automation.Language.CommandAst] -and
                $args[0].Extent.StartOffset -ne $args[0].Parent.Extent.StartOffset
            }, $true)

        if ($asts.Count -eq 0) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
            return
        }

        $nextAst = $null

        if ($null -ne $arg) {
            $nextAst = $asts[$arg - 1]
        }
        else {
            foreach ($ast in $asts) {
                if ($ast.Extent.StartOffset -ge $cursor) {
                    $nextAst = $ast
                    break
                }
            }

            if ($null -eq $nextAst) {
                $nextAst = $asts[0]
            }
        }

        $startOffsetAdjustment = 0
        $endOffsetAdjustment = 0

        if ($nextAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $nextAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord) {
            $startOffsetAdjustment = 1
            $endOffsetAdjustment = 2
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($nextAst.Extent.StartOffset + $startOffsetAdjustment)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetMark($null, $null)
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar($null, ($nextAst.Extent.EndOffset - $nextAst.Extent.StartOffset) - $endOffsetAdjustment)
    }


    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows


    # This is an example of a macro that you might use to execute a command.
    # This will add the command to history.
    Set-PSReadLineKeyHandler -Key Ctrl+Shift+b `
        -BriefDescription BuildCurrentDirectory `
        -LongDescription "Build the current directory" `
        -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet build")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    Set-PSReadLineKeyHandler -Key Ctrl+Shift+t `
        -BriefDescription BuildCurrentDirectory `
        -LongDescription "Build the current directory" `
        -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet test")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    # Key handler to expend this to current command line(Note: get the current git branch and append to $current_branch): `git c -am "$current_branch"`
    Set-PSReadLineKeyHandler -Key Alt+n `
        -BriefDescription CommitCurrentBranch `
        -LongDescription "Commit the current branch" `
        -ScriptBlock {
        # check if the current directory is a git repository?
        # if yes, get the current branch
        # if no, do nothing

        $dir = Get-Item -Path "." -Verbose
        $max_checks = 10
        $checks = 0
        $current_branch = ''

        while ($dir -ne $null -and $dir.Name -ne "C:\" -and $checks -lt $max_checks) {
            if (Test-Path -Path "$dir\.git" -PathType Container) {
                $current_branch = git rev-parse --abbrev-ref HEAD
                break
            }
            $dir = $dir.Parent
            $checks += 1
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("git c -am '$current_branch'")
        #navigate back one character
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar()
        # [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }


    Set-PSReadLineKeyHandler -Key Alt+m `
        -BriefDescription CommitAlias `
        -LongDescription "Append commit alias to command line" `
        -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("git c -am ''")
        #navigate back one character
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar()
        # [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    # key handler alt + b to back to the previous directory
    Set-PSReadLineKeyHandler -Key Alt+b `
        -BriefDescription BackToPreviousDirectory `
        -LongDescription "Back to the previous directory" `
        -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("cd ..")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    # key handler alt + h to navigate to $HUYNH_CONFIG_DIR
    Set-PSReadLineKeyHandler -Key Alt+h `
        -BriefDescription NavigateToConfig `
        -LongDescription "Navigate to $HUYNH_CONFIG_DIR" `
        -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("cd $env:HUYNH_CONFIG_DIR")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

}

Run-Step "Alias & Handler" {
    setAliasAndKeyBinding
}

## Function
function enterGitbash {
    # add try catch
    try {
        & 'C:\Program Files\Git\bin\sh.exe' --login
    }
    catch {
        Write-Host "Error: Git Bash not found"
    }
}

# function prompt {
#     $loc = $executionContext.SessionState.Path.CurrentLocation;

#     $out = "PS $loc$('>' * ($nestedPromptLevel + 1)) ";
#     if ($loc.Provider.Name -eq "FileSystem") {
#         $out += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
#     }
#     return $out
# }

## ALIAS
set-alias gbash "enterGitbash"
# set alias `blg` will open https://gogojungle.backlog.jp/view/${current git branch name}
function openBackLogGgj {
    $branch = git rev-parse --abbrev-ref HEAD
    $url = "https://gogojungle.backlog.jp/view/$branch"
    start $url
}
set-alias blg openBackLogGgj

function GitStatus { & git status $args }
set-alias gs GitStatus

# Alias to run command as administrator
function openAdminTerminal {
    # open a new terminal as admin at the current directory
    $current_dir = Get-Location
    $admin_terminal = "C:\Users\congh\AppData\Local\Microsoft\WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe"

    # check admin_terminal exists
    if (!(Test-Path $admin_terminal)) {
        Write-Host "Warning: $admin_terminal not found"
        Write-Host "Please install powershell from Microsoft Store or correct the path"
        Write-Host "Using built-in powershell instead"
        Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -Command cd $current_dir"
        return
    }
    # open a new terminal not as admin at the current directory
    Start-Process -FilePath $admin_terminal -Verb RunAs -ArgumentList "-NoExit -Command cd $current_dir"

}
set-alias admin openAdminTerminal

function copyCurrentDIR { Get-Location | Set-Clipboard }

set-alias cpdir copyCurrentDIR

function removeDockerContainerByID {
    $container_name = $args[0]
    $container_id = docker ps -a -q --filter ancestor=$container_name --format "{{.ID}}"
    Write-Host "container_id: $container_id"
    Write-Host "container_id: $container_name"
    docker rm $container_id -f
}

set-alias rmc removeDockerContainerByID

function stopDockerContainerByID {
    $container_name = $args[0]
    $container_id = docker ps -a --filter ancestor=$container_name --format "{{.ID}}"
    docker stop $container_id
}

set-alias stc stopDockerContainerByID

# implement function to copy previous command output to clipboard
# example:
#   previous command: echo Hello
#   output: Hello
#   next command copypre
#   clipboard: Hello
function copyPreviousOutput {
    $previous_command = Get-History -Count 1
    $previous_command_output = Invoke-Expression $previous_command
    if($previous_command_output -eq $null) {
        Write-Host "No previous command output found"
        return
    }

    $previous_command_output | Set-Clipboard
}
set-alias cppre copyPreviousOutput

function getDockerImagesIdByName {
    $image_name = $args[0]
    $image_id = docker images -q $image_name
    if($image_id -eq $null) {
        Write-Host "No image found"
        return
    }
    Write-Host "image_id: $image_id"
    Write-Host "image_name: $image_name"
    $image_id | Set-Clipboard
    Write-Host "Copied images_id to clipboard" -ForegroundColor Green

}
set-alias gii getDockerImagesIdByName

function removeDockerImagesByName {
    $image_name = $args[0]
    $image_id = docker images -q $image_name
    if($image_id -eq $null) {
        Write-Host "No image found"
        return
    }
    Write-Host "image_id: $image_id"
    Write-Host "image_name: $image_name"
    docker rmi $image_id -f
}
set-alias rmi removeDockerImagesByName