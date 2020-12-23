import macros
import strutils
import parseutils
import strformat, strutils
import asyncdispatch
import strscans
import std/with
from dimscord import Message

type
    Command = object
        name: string
        prc: NimNode
        # The approach of storing NimNode and building the code for later works nice and plays nicely with unittesting
        # But it doesn't seem the cleanest I understand
        # For now though I will keep it like this until I see how slash commands are implemented in dimscord
        help: string
        parameters: seq[(string, string)]

# A global variable is not a good idea but it works well
var dimscordCommands {.compileTime.}: seq[Command]

proc getDoc(prc: NimNode): string =
    ## Gets the doc string for a function
    for node in prc:
        if node.kind == nnkStmtList:
            for innerNode in node:
                if innerNode.kind == nnkCommentStmt:
                    return innerNode.strVal

proc getParameters(prc: NimNode): seq[(string, string)] =
    ## Gets the both the name and type of each parameter and returns it in a sequence
    ## [0] is the name of the parameter
    ## [1] is the type of the parameter
    for node in prc:
        if node.kind == nnkFormalParams:
            for paramNode in node:
                if paramNode.kind == nnkIdentDefs:
                    result.add((paramNode[0].strVal, paramNode[1].strVal))

proc command(prc: NimNode, name: string) =
    ## **INTERNAL**
    ## This is called by the `command` pragmas
    var newCommand: Command
    with newCommand:
        # Set the name of the command
        name = name
        # Set the help message
        help = prc.getDoc()
        # Set the types
        parameters = prc.getParameters()
        # Add the code
        prc = prc.body()
    dimscordCommands.add newCommand

macro ncommand*(name: string, prc: untyped) =
    ## Use this pragma to add a command with a different name to the proc
    ##
    ## .. code-block::
    ##    proc cmdPing() {.ncommand(name = "ping").} =
    ##        # TODO add ping command
    ##
    command(prc, name.strVal())

macro command*(prc: untyped) =
    ## Use this pragma to add a command with the same name as the proc
    ##
    ## .. code-block::
    ##    proc ping() {.command.} =
    ##        # TODO add ping command
    ##
    command(prc, prc.name().strVal())

proc getStrScanSymbol(typ: string): string =
    ## Gets the symbol that strscan uses in order to parse something of a certain type
    case typ:
        of "int": "$i"
        of "string": "$w"
        else: ""

proc addParameterParseCode(prc: NimNode, parameters: seq[(string, string)]): NimNode =
    ## **INTERNAL**
    ## This injects code to the start of a block of code which will parse cmdInput and set the variables for the different parameters
    ## Currently it only supports int and string parameter types
    ## This is achieved with the strscans module
    if len(parameters) == 0: return prc # Don't inject code if there is nothing to parse
    result = newStmtList()
    var scanPattern: string
    # Add all the variables which will be filled with the scan
    for parameter in parameters:
        scanPattern &= getStrScanSymbol(parameter[1]) & " " # Add a space since the parameters are seperated by a space
        result.add parseExpr fmt"var {parameter[0]}: {parameter[1]}"
    scanPattern = scanPattern.strip()  # Remove final space so that it matches properly
    # Add in the scanning code
    var scanfCall = nnkCall.newTree(
        ident("scanf"),
        ident("cmdInput"),
        newLit(scanPattern)
    )
    for parameter in parameters:
        scanfCall.add ident(parameter[0])
    result.add quote do:
        if `scanfCall`:
            `prc`

macro buildCommandTree*(): untyped =
    ## **INTERNAL**
    ##
    ## Builds a case stmt with all the dimscordCommands.
    ## It requires that cmdName and cmdInput are both defined in the scope that it is called in
    ## This is handled by the library and the user does not need to worry about it
    ##
    ## * cmdName is the parsed name of the command that the user has sent
    ## * cmdInput is the extra info that the user has sent along with the string
    if dimscordCommands.len() == 0: return
    result = nnkCaseStmt.newTree(ident("cmdName"))
    for command in dimscordCommands:
        result.add nnkOfBranch.newTree(
            newStrLitNode(command.name),
            command.prc.addParameterParseCode(command.parameters)
        )

proc generateHelpMsg(): string {.compileTime.} =
    ## Generates the help message for the bot
    ## The help string for each command is retrieved from the doc string in the proc
    for command in dimscordCommands:
        if command.help != "":
            result.add fmt"{command.name}: {command.help}"

proc findTokens(input: string, startPosition: int = 0): seq[string] =
    ## Finds all the tokens in a string
    ## A token can be a word, character, integer or a combination of them
    ## This helps with parseing a command from the user that might have irregular use of whitespace
    var position = startPosition
    while position < len(input):
        ## Skip past any whitespace
        position += skipWhitespace(input, start = position)
        ## Parse the token that comes after all the whitespace
        var nextToken: string
        let tokenLen = parseUntil(input, nextToken, until = " ",start = position)
        if tokenLen != 0: # If tokenLen is zero then it means there is a parsing error, most likely the end of the string
            position += tokenLen
            result   &= nextToken
        else:
            break

proc getCommandComponents(prefix, message: string): tuple[name: string, input: string] =
    ## Finds the two components of a command.
    ## This will be altered later once subgroups/subcommands are implemented.
    if message.startsWith(prefix):
        let tokens   = findTokens(message, len(prefix))
        if tokens.len == 0: return # Return empty if nothing is found
        result.name  = tokens[0]
        if tokens.len >= 1: # Only set input if there are more tokens
            result.input = tokens[1..^1].join(" ")
    echo result
    
template commandHandler*(prefix: string, m: Message) =
    ## This is placed inside your message_create event like so
    ##
    ## .. code-block::
    ##    discord.events.message_create = proc (s: Shard , m: Message) {.async.} =
    ##        commandHandler("$$", m)
    ##
    # This is a template since buildCommandTree has to be run after all the commands have been added

    if m.content.startsWith(prefix):  # Dont waste time if it doesn't even have the prefix
        let
            cmdComponents = getCommandComponents(prefix, m.content)
            cmdName {.inject.} = cmdComponents.name
            cmdInput {.inject.} = cmdComponents.input
        if cmdName == "":
            break
        buildCommandTree()

export parseutils
export strscans
