import macros
import strutils
import std/with
import parseutils
import tables

## Utilites for use in macros

type
    ProcParameter* = tuple[name: string, kind: string, help: string]

const
    optionPrefixes* = {'$', '%'} ## $ means variables, % means variable help

proc getDoc*(prc: NimNode): string =
    ## Gets the doc string for a function
    for node in prc:
        if node.kind == nnkStmtList:
            for innerNode in node:
                if innerNode.kind == nnkCommentStmt:
                    return innerNode.strVal


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

proc getParameters*(prc: NimNode): seq[ProcParameter] =
    ## Gets the both the name, type, and help message of each parameter and returns it in a sequence
    # TODO allow developer to use a pragma to set help message
    for node in prc:
        if node.kind == nnkFormalParams:
            let options = parseOptions(prc)
            for paramNode in node:
                if paramNode.kind == nnkIdentDefs:
                    var parameter: ProcParameter
                    with parameter:
                        name = paramNode[0].strVal
                        kind = $paramNode[1].toStrLit # toStrLit is used since it works better with types that are Option[T]
                        help = options.getOrDefault("%" & parameter.name)
                    result.add parameter
export tables
