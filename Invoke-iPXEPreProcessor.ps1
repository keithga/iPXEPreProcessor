<#
.Synopsis
    iPXE Script Pre-Processor
.DESCRIPTION
    Allows a iPXE script to include if, while, sub, and include, 
    to reduce the need for gotos, target can be understood by the iPXE.org interpreter.
.NOTES
    Will allow for the use of the following constructs:

    Add ipxe script <path> into current ipxe script.
#include <path> # Comments...

    If command
if ( [not] <ipxecommand> [args...] ) # Comments...
else   # Comments...
end if   # Comments...

    while command
while ( [not] <ipxecommand> [args...] )  # Comments...
end while  # Comments...
break  # Comments...
continue  # Comments...

    subroutine commands
sub <subroutinename>  # Comments...
call <subroutinename> [args..] # Comments...
return # Comments...
end sub # Comments...

.EXAMPLE
invoke-iPXEPreProcessor.ps1 .\sample.sh > Output.ipxe
.LINK 
    https://homepages.cwi.nl/~storm/teaching/reader/Dijkstra68.pdf
.LINK 
    https://github.com/keithga/iPXEPreProcessor
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory,Position=0)]
    [string] $Path,
    [Parameter(Position=1)]
    [int] $StartingLabel = 0
)

if ( $StartingLabel -eq 0 ) { cls }

$CommandStack = [System.Collections.Stack]::new()

#region For each line in the script
foreach ( $line in Get-Content -Path $path ) {

    #region Remove comments

    if ( $line -match '^\s*##\s.*$' ) {
        # if comment starts with ##, then obmit
    }

    elseif ( $line -match '^\s*(?<op>#region|#endregion)\s*(.*)?$' ) {
        # Regions are useful in vscode, but not useful in ipxe, obmit 
    }

    #endregion

    #region INCLUDE
    elseif ( $line -match '^\s*\#?(INCLUDE|include)\b\s*(?<Path>[^\#]*)\s*(\#.*)?$' ) {
        # example: #include <path> # Comments...

        

        "# $($line)" | write-output          

        #Find include file, it could be in several places:
        $found = $null
        if ( test-path ( join-path (Split-path $Path) $Matches.path ) ) {
            # Relative to the parent file.
            $found = (join-path (Split-path $Path) $Matches.path)
        }
        elseif ( test-path ( $Matches.path ) ) {
            # Found via absoulue path ( or relative to current directory )
            $found = $Matches.path
        }
        else { 
            throw "Not found: $($matches.path)"
        }

        if ( ! $found ) { 
            throw "nested script not found: $Line"
        }

        if ( $MyInvocation.MyCommand.path ) {
            & $MyInvocation.MyCommand.path -startinglabel $StartingLabel -path $Found

        }
        elseif ( $MyInvocation.MyCommand.ScriptBlock ) {
            invoke-command -ScriptBlock $MyInvocation.MyCommand.ScriptBlock -ArgumentList @( $Found, $StartingLabel + 1 )
        }
        else {
            $MyInvocation.MyCommand | Fl * | out-string | write-verbose
            throw "this Pre-Parsing script not found"
        }
    }

    #endregion

    #region IF

    elseif ( $line -match '^\s*\b(?<op>(if))\b\s*\(\s*(?<not>(not|NOT|!))?\s+(?<cmd>[^\)]*)\s*\)\s*(\#.*)?$' ) {

        # example: if ( [not] <ipxecommand> [args...] ) # Comments...

        $label = "$($matches.op.tolower())_{0:X4}" -f ( ++$StartingLabel )
        if ( $matches.not -eq 'not' ) {
@"
# $($Line)
$($matches.cmd) && goto $($label)_else || 
"@ | write-output
        }
        else {
@"
# $($Line)
$($matches.cmd) || goto $($label)_else
"@ | Write-Output
        }

        $matches.add('label',$label)
        $CommandStack.push( $matches )
       
    }

    elseif ( $line -match '^\s*\b(?<op>(else))\b\s*(\#.*)?$' ) {
        # example:    else   # Comments...

        # Verify the current command.
        $CurrentCommand = $commandstack.pop()
        $label = $CurrentCommand.label
        if ( $CurrentCommand.op -ne 'if' ) { throw "else is not matching to an IF command" }
        
@"
goto $($label)_end
# $($Line)
:$($label)_else
"@ | write-output

        $matches.add('label',$label)
        $CommandStack.push( $matches )
       
    }

    elseif ( $line -match '^\s*\b(?<op>(elseif))\b\s*\(\s*(?<not>(not|NOT|!))?\s+(?<cmd>[^\)]*)\s*\)\s*(\#.*)?$' ) {
        throw "Future idea, not supported yet..."
    }
    elseif ( $line -match '^\s*\b(?<op>(endif|end if))\b\s*(\#.*)?$' ) {
        # example:    end if   # Comments...

        # Verify the current command.
        $CurrentCommand = $commandstack.pop()
        $label = $CurrentCommand.label
        if ( $CurrentCommand.op -notmatch '(if|else)' ) { throw "else is not matching to an IF command" }
        if ( $CurrentCommand.op -eq 'if' ) {
            ":$($label)_else" # make this the else label too
        }
@"
# $($Line)
:$($label)_end
"@ | write-output
       
    }

    #endregion 

    #region WHILE

    elseif ( $line -match '^\s*\b(?<op>(while))\b\s*\(\s*(?<not>(not|NOT|!))?\s+(?<cmd>[^\)]*)\s*\)\s*(\#.*)?$' ) {
        # example: while ( [not] <ipxecommand> [args...] )  # Comments...


        $label = "$($matches.op.tolower())_{0:X4}" -f ( ++$StartingLabel )
        if ( $matches.not -eq 'not' ) {
@"
# $($Line)
:$($label)_start
$($matches.cmd) && goto $($label)_end || 
"@ | write-output
        }
        else {
@"
# $($Line)
:$($label)_start
$($matches.cmd) || goto $($label)_end
"@ | Write-Output
        }

        $matches.add('label',$label)
        $CommandStack.push( $matches )
       
    }

    elseif ( $line -match '^\s*\b(?<op>(wend|end while))\b\s*(\#.*)?$' ) {
        # example:    end while  # Comments...

        # Verify the current command.
        $CurrentCommand = $commandstack.pop()
        $label = $CurrentCommand.label
        if ( $CurrentCommand.op -notmatch '(while)' ) { throw "end while is not matching to an WHILE command" }
@"
# $($Line)
goto $($label)_start
:$($label)_end
"@ | write-output
       
    }

    elseif ( $line -match '^\s*\b(?<op>(break|continue))\b\s*(\#.*)?$' ) {
        # example:   break  # Comments...
        # example:   continue  # Comments...

        # find the while command in the commandstack
        if ( $matches.op -eq 'continue' ) { $Target = 'start' } else { $target = 'end' }
        $currentCommand = $commandStack.ToArray() | ? { $_.op -match 'while' } | select-object -last 1
        if ( $CurrentCommand.op -notmatch '(while)' ) { throw "end while is not matching to an WHILE command" }
        $label = $CurrentCommand.label
@"
# $($Line)
goto $($label)_$($target)
"@ | write-output
     
    }

    #endregion

    #region Call SUB, return 

    elseif ( $line -match '^\s*\#?(?<op>sub)\b\s*(?<name>[a-zA-Z_-]*)\s*(\#.*)?$' ) {
        # example:   sub <subroutinename>  # Comments...

        $label = "$($matches.name.tolower())"
@"
# $Line
:sub_$($label)
"@ | write-output

        $matches.add('label',$label)
        $CommandStack.push( $matches )
    }

    elseif ( $line -match '^\s*\#?(?<op>call)\b\s*(?<name>[a-zA-Z_-]*)\s*(?<arg>.*)$' ) {
        # example:   call <subroutinename> [args..] # Comments...

        $label = "$($matches.name.tolower())_{0:X4}" -f ( ++$StartingLabel )    

        if (![string]::IsNullOrEmpty($matches.arg)) { 
            $i = 0
            # Simple argument parsing with some support for quoted strings (mostly untested):   arg1 arg2 "arg3a arg3b arg3c" arg4
            # arguments are stored in GLOBAL variables, not on the stack, nested calling of subroutines are discouraged.
            foreach ( $Myarg in ($matches.arg | select-string -Pattern '[\""].+?[\""]|[^ ]+' -AllMatches | % matches | % Value ) ) { 
                $i = $i + 1
                "set arg$($i) $($MyArg)" | Write-Output
            }
        }

@"
# $Line
set $($matches.name.tolower())_return $($label)_returnpoint
goto sub_$($matches.name.tolower()) ||
:$($label)_returnpoint

"@ | write-output

    }

    elseif ( $line -match '^\s*\b(?<op>(return))\b\s*(\#.*)?$' ) {
        # example:   return # Comments...
        # note: no support for returning values

        # find the sub command in the commandstack
        $currentCommand = $commandStack.ToArray() | ? { $_.op -match 'sub' } | select-object -last 1
        if ( $CurrentCommand.op -notmatch '(sub)' ) { throw "end sub is not matching to an SUB statement" }
        $label = $CurrentCommand.label
@"
# $($Line)
goto $($label)_end
"@ | write-output
     
    }

    elseif ( $line -match '^\s*\b(?<op>(endsub|end sub))\b\s*(\#.*)?$' ) {
        # example:    end sub # Comments...

        # Verify the current command.
        $CurrentCommand = $commandstack.pop()
        $label = $CurrentCommand.label
        if ( $CurrentCommand.op -notmatch '(sub)' ) { throw "end sub is not matching to an SUB command" }
@"
# $($Line)
:$($label)_end
goto `${$($label)_returnto}
"@ | write-output
       
    }
    
    #endregion

    #region Console output

    elseif ( $line -match '^\s*(?<op>echo|item|prompt)\s*(?<string>\"[^\#]*)\s*(\#.*)?$' ) {

        # For text written to console, iPXE will trim all consecutive whitespace to a single space.
        # To allow for text alignment, we can add an empty escape:  From: "  " to " ${} "
        # This feature is only applicable for echo|item|prompt lines contain Double Quotes.

        "$($matches.op) $($matches.string.trim('"') -replace ' (?= )',' ${}' )"  | write-output

    }

    else {
        # all other lines are written to stdout.
        $line | write-output
    }

    #endregion

}
#endregion

if ( $commandStack.Count -ne 0 ) { 
    $commandStack | ft | out-string | Write-verbose
    throw "Extra commands left on stack"
}
