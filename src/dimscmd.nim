import macros
import strutils
import parseutils
import strformat, strutils
import asyncdispatch
import strscans
from dimscord import Message

type
    Command = object
        name: string
        prc: NimNode
        help: string
        types: seq[(string, string)] # TODO settle on either types or parameters has this name

# A global variable is not a good idea but it works well
var dimscordCommands {.compileTime.}: seq[Command]

template cmd*(name: string) {.pragma.}

proc getDoc(prc: NimNode): string =
    ## Gets the doc string for a function
    for node in prc:
        if node.kind == nnkStmtList:
            for innerNode in node:
                if innerNode.kind == nnkCommentStmt:
                    return innerNode.strVal

proc getTypes(prc: NimNode): seq[(string, string)] =
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
    # Set the name of the command
    newCommand.name = name
    # Set the help message
    newCommand.help = prc.getDoc()
    # Set the types
    newCommand.types = prc.getTypes()
    # Add the code
    newCommand.prc = prc.body()
    dimscordCommands.add newCommand

macro ncommand*(name: string, prc: untyped) =
    echo name
    command(prc, name.strVal())

macro command*(prc: untyped) =
    echo prc.name().strVal()
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
    ## Builds a case stmt with all the dimscordCommands
    ## It requires that cmdName and cmdInput are both defined in the scope that it is called
    ## cmdName is the parsed name of the command that the user has sent
    ## cmdInput is the extra info that the user has sent along with the string
    if dimscordCommands.len() == 0: return
    result = nnkCaseStmt.newTree(ident("cmdName"))
    for command in dimscordCommands:
        result.add nnkOfBranch.newTree(
            newStrLitNode(command.name),
            command.prc.addParameterParseCode(command.types)
        )

    echo result.toStrLit()

proc generateHelpMsg(): string {.compileTime.} =
    ## Generates the help message for the bot
    ## The help string for each command is retrieved from the doc string in the proc
    for command in dimscordCommands:
        if command.help != "":
            result.add fmt"{command.name}: {command.help}"

template commandHandler*(prefix: string, m: Message) {.dirty.} =
    ## This is placed inside your message_create event like so
    ##
    ## .. code-block::
    ##    discord.events.message_create = proc (s: Shard , m: Message) {.async.} =
    ##        commandHandler("$$", m)
    ##
    # This is a template since buildCommandTree has to be run after all the commands have been added

    if m.content.startsWith(prefix):  # Dont waste time if it doesn't even have the prefix
        let
            cmdName {.inject.} = parseIdent(m.content, start = len(prefix))
            cmdInput {.inject.} = m.content[(len(prefix) + len(cmdName) + 1)..^1] # Add the length of the prefix and the command name and add 1 (to remove the space)
        echo(cmdInput)
        if cmdName == "":
            break
        buildCommandTree()

export parseutils
export strscans
