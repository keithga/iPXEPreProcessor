# iPXEPreProcessor
Pre-Processor for iPXE scripting Language

## Background
Goto's are considered harmful, really they are just a pain.

The iPXE scripting language was designed to be as lightweight as possible, 
but it looses out on several higher level scripting constructs like IF, WHILE, and SUB. 
This script will translate a specially formatted iPXE script with these constructs into iPXE scripting syntax.

Take for example an IF statement:
```
if ( ping google.com )
    echo Google responded
else
    echo Could not ping google.com
end if
```
this can be translated into iPXE format:
```
ping google.com && || goto if_0001_else
    echo Google responded
    goto if_0001_end
:if_0001_else
    echo Could not ping google.com
:if_0001_end
```

I decided to write this from scratch, and share with the iPXE community.

# Commands:

## IF 
Standard IF statement against a single iPXE command and test the output.
### Syntax
```
if ( [not] <ipxecommand> [args...] ) # Comments...
    echo true if
else   # Comments...
    echo false if
end if   # Comments...
```
Must include the closing `end if` statement, `else` is optional. `NOT` ( or `!` ) will test the negative case.
There can be any number of arguments passed to the test command. 

## WHILE 
Standard While loop statement against a single iPXE command and test the output.
### Syntax
```
while ( [not] <ipxecommand> [args...] )  # Comments...
    echo Looping...
    if ( ping google.com )
         break # Comments...
    end if
    if ( ping 8.8.8.8 )
        continue # Comments...
    end if
end while  # Comments...
```
Must include the closing `end while` statement, `NOT` ( or `!` ) will test the negative case.
There can be any number of arguments passed to the test command. 
`break` will exit the while loop. `continue` will jump back to the start of the while loop.

## INCLUDE 
Include another iPXE script in this file.
### Syntax
```
#include <path> # Comments...
```
The Path can be relative to the existing script, the current directory, or the path must be absolute. 
The sub-script is pre-parsed before importing.

## SUB 
Subroutine Commands
### Syntax
```
sub <subroutinename>  # Comments...
    return # Comments...
end sub # Comments...
call <subroutinename> [args..] # Comments...
```
Calls a subroutine, really just a goto jump, where the subroutine keeps track of where to jump BACK to. 
call will accept a number of arguments, stored as global variables arg1, arg2, arg3 respectively. 

forexample:
```
call  mysubroutine One Two "Three Tres Drei"
```
turns into:
```
set arg1 One
set arg2 Two
set arg3 "Three Dres Drei"
```

## echo 
console formatting
### Syntax
```
echo  This     Line     will     NOT    show    extra                    spaces
echo "This     Line     will            SHOW    extra                    spaces"
```
For text written to console, iPXE will trim all consecutive whitespace to a single space.
To allow for text alignment, we can add an empty escape:  From: `"  "` to `" ${} "`
This feature is only applicable for `echo` `item` `prompt` lines contain Double Quotes.

# Other Programming Notes

* Save your script with the .sh file extension. Visual Studio code will do a pretty good job of dispalying the iPXE code. THen save the output as *.ipxe for execution.
* Lines with `#region` and `#endregion` are striped out.
* Lines that start with `##` are removed.
