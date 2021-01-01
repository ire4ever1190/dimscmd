# parsing said the spy
import strutils
import parseutils
import macroUtils
import tables

const
    optionPrefixes = {'$', '%'} ## $ means variables, % means variable help

proc makeInsensitive(input: string): string =
    ## Makes a string lowercase and replaces underscores with spaces
    ## This is used with the option parsing to make it insensitive like nim variables
    input
        .replace("_", "")
        .toLowerAscii()
        
proc hasPrefix(input: string): bool =
    result = len(input) > 0 and input[0] in optionPrefixes 

proc getDocNoOptions*(prc: NimNode): string =
    ## Gets the doc string of a procedure without getting the options
    for line in prc.getDoc().split("\n"):
        if not line.hasPrefix():
            result &= line


proc parseOptions*(input: string): Table[string, string] =
    ## Parses a string in the form
    ##       name: value
    ## This is used to make configuration possible within the doc string of a procedure.
    ## This is done to get around the limitation (Or my lack of ability) to have optional parameters in a pragma.
    ## The options are returned in lowercase and all underscores removed
    let saneInput = input.multiReplace { # Replace all whitespace
        " ": "",
        "\t": ""
    }
    for line in saneInput.split("\n"):
        if line.hasPrefix():
            var 
                name: string
                value: string
            let nameEnd = parseUntil(line, name, until = ":") + 1 # Plus two is needed to skip :
            discard parseUntil(line, value, until = "\n", start = nameEnd)
            result[name.makeInsensitive()] = value

proc parseOptions*(prc: NimNode): Table[string, string] =
    ## Parses options from a procedures doc string
    result = prc.getDoc().parseOptions()
    
export tables
