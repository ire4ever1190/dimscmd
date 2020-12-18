import macros
import strutils
import parseutils
import strformat
import asyncdispatch
from dimscord import Message

type
    Command = object
        name: string
        prc: NimNode
        help: string
        types: seq[(string, string)] # The signiture of the proc is stored has a sequence of strings

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
    for node in prc:
        if node.kind == nnkFormalParams:
            for paramNode in node:
                if paramNode.kind == nnkIdentDefs:
                    result.add((paramNode[0].strVal, paramNode[1].strVal))

macro command*(prc: untyped, name: string = ""): void =
    ## Use this pragma to add a command to the handler.
    ## If a name is not specified then the name of the proc is used has the command name
    #echo prc.getImpl[0]
    var newCommand: Command
    echo prc.astGenRepr()
    # Set the name of the command
    if prc.hasCustomPragma(cmd):
      newCommand.name = prc.getCustomPragmaVal(name).strVal()
    else:
      newCommand.name = prc.name().strVal()
    # Set the help message
    newCommand.help = prc.getDoc()
    # Set the types
    newCommand.types = prc.getTypes()
    # Add the code
    newCommand.prc = prc.body()
    echo newCommand.types
    dimscordCommands.add newCommand

macro buildCommandTree*(): untyped =
    ## **INTERNAL**
    ## Builds a case stmt with all the dimscordCommands
    if dimscordCommands.len() == 0: return
    result = nnkCaseStmt.newTree(ident("cmdName"))
    for command in dimscordCommands:
        result.add nnkOfBranch.newTree(
            newStrLitNode(command.name),
            command.prc
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
        let cmdName {.inject.} = parseIdent(m.content, start = len(prefix))
        if cmdName == "": break # TODO send an error message to the user that they have not specified any command
        buildCommandTree()

export parseutils
