import macros
import strutils
import parseutils
import strformat, strutils
import asyncdispatch
import strscans
import std/with
import options
import dimscord
import tables
import sugar
import macroUtils
import parsing
import commandOptions

# TODO, learn to write better documentation
## Commands are registered using with the .command. pragma or the .slashcommand. pragma.
## The .command. pragma is used for creating commands that the bot responds to in chat.
## The .slashcommand. pragma is used for creating commands that the bot responds to when using slash commands.
##
## If you are using slash commands then you must register the commands.
## This is done in your bots onReady event like so.
##
## ..code-block ::
##    proc onReady (s: Shard, r: Ready) {.event(discord).} =
##        await discord.api.registerCommands("742010764302221334") # You must pass your application ID which is found on your bots dashboard
##        echo "Ready as " & $r.user
##
## An issue with pragmas is that you cannot have optional parameters (or I am not smart enough to know how) and so this library uses the
## doc string of a procedure to provide further config. These are called doc options and are used like so
##
## .. code-block::
##    proc procThatYouWantToProvideOptionsFor() {.command.} =
##        ## $name: value # Variable must start with $
##        discard    

template pHelp*(msg: string) {.pragma.}

type
    CommandType* = enum
        ## A chat command is a command that is sent to the bot over chat
        ## A slash command is a command that is sent using the slash commands functionality in discord
        ctChatCommand
        ctSlashCommand
    
    ChatCommandProc = proc (m: Message): Future[void] # The message variable is exposed has `msg`
    SlashCommandProc = proc (i: Interaction): Future[void] # The Interaction variable is exposed has `i`

    Command = object
        name: string
        description: string
        parameters: seq[ProcParameter]
        case kind: CommandType
            of ctSlashCommand:
                guildID: string
                options: seq[ApplicationCommandOption]
            of ctChatCommand:
                discard
    
    CommandHandler = ref object
        discord: DiscordClient
        msgVariable: string
        # TODO move from a table to a tree like structure. It will allow the user to declare command groups if they are in a tree
        chatCommands: Table[string, tuple[handler: ChatCommandProc, command: Command]]
        slashCommands: Table[string, tuple[handler: SlashCommandProc, command: Command]]

proc newHandler*(discord: DiscordClient, msgVariable: string = "msg"): CommandHandler =
    return CommandHandler(discord: discord, msgVariable: msgVariable)

proc getStrScanSymbol(typ: string): string =
    ## Gets the symbol that strscan uses in order to parse something of a certain type
    case typ:
        of "int": "$i"
        of "string": "$w"
        of "Channel": "#$w>"
        else: ""

proc scanfSkipToken*(input: string, start: int, token: string): int =
    ## Skips to the end of the first found token.
    ## Returns 0 if the token was not found
    var index = start
    template notWhitespace(): bool = not (input[index] in Whitespace)
    while index < input.len:
        echo input[index]
        if index < input.len and notWhitespace:
            let identStart = index
            #inc index
            var tokenIndex = 0
            echo "input index ", input[index], " should be ", token[tokenIndex]
            while index < input.len and input[index] == token[tokenIndex]:
                inc index
                inc tokenIndex
            let ident = substr(input, identStart, index - 1)
            echo ident
            if ident == token:
                return index - start
        inc index

proc addChatParameterParseCode(prc: NimNode, name: string, parameters: seq[ProcParameter]): NimNode =
    ## **INTERNAL**
    ## This injects code to the start of a block of code which will parse cmdInput and set the variables for the different parameters
    ## Currently it only supports int and string parameter types
    ## This is achieved with the strscans module
    if len(parameters) == 0: return prc # Don't inject code if there is nothing to parse
    result = newStmtList()
    var scanPattern = &"$[scanfSkipToken(\"{name}\")]$s"
    # Add all the variables which will be filled with the scan
    for parameter in parameters:
        scanPattern &= getStrScanSymbol(parameter[1]) & "$s" # Add a space since the parameters are seperated by a space
        case parameter[1]:
            of "Channel":
                result.add parseExpr fmt"var {parameter[0]}: string"
            else:
                result.add parseExpr fmt"var {parameter[0]}: {parameter[1]}"
    scanPattern = scanPattern.strip()  # Remove final space so that it matches properly
    # Add in the scanning code
    var scanfCall = nnkCall.newTree(
        ident("scanf"),
        ident("msg").newDotExpr(ident("content")),
        newLit(scanPattern)
    )
    for parameter in parameters:
        scanfCall.add ident(parameter[0])
    result.add quote do:
        if `scanfCall`:
            `prc`
    echo result.toStrLit()

proc register*(router: CommandHandler, name: string, handler: ChatCommandProc) =
    var newCommand: tuple[handler: ChatCommandProc, command: Command]
    newCommand.handler = handler
    router.chatCommands[name] = newCommand


proc register*(router: CommandHandler, name: string, handler: SlashCommandProc) =
    router.slashCommands[name].handler = handler

macro addChat*(router: CommandHandler, name: static[string], handler: untyped): untyped =
    ## Add a new chat command to the handler
    ## A chat command is a command that the bot handles when it gets sent a message
    var newCommand: Command
    let 
        procName = newIdentNode(name & "Command") # The name of the proc that is returned 
        parameters = handler.getParameters()
        body = handler.body.addChatParameterParseCode(name, parameters)
        msgVariable = "msg".ident()
    result = newStmtList()
    result.add quote do:
        proc `procName`(`msgVariable`: Message) {.async.} =
            `body`

    result.add quote do:
        `router`.register(`name`, `procName`)


proc getHandler(router: CommandHandler, name: string): ChatCommandProc =
    ## Returns the handler for a command with a certain name
    result = router.chatCommands[name].handler

proc handleMessage*(router: CommandHandler, prefix: string, msg: Message): Future[bool] {.async.} =
    ## Handles an incoming discord message and executes a command if necessary.
    ## This returns true if a command was found and executed
    ## 
    ## ..code-block:: nim
    ## 
    ##    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    ##        discard await router.handleMessage("$$", msg)
    ##     
    if not msg.content.startsWith(prefix): return
    let startWhitespaceLength = skipWhitespace(msg.content, len(prefix))
    var name: string
    discard parseUntil(msg.content, name, start = len(prefix) + startWhitespaceLength, until = Whitespace)
    if router.chatCommands.hasKey(name):
        let handler = router.getHandler(name)
        await handler(msg)
        result = true

proc handleMessage*(router: CommandHandler, prefixes: openarray[string], msg: Message): Future[bool] {.async.} =
    ## Handles an incoming discord message and executes a command if necessary.
    ## This returns true if a command was found and executed. It will return once a prefix is correctly found
    ## 
    ## ..code-block:: nim
    ## 
    ##    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    ##        discard await router.handleMessage(["$$", "&"], msg)
    ##
    for prefix in prefixes:
        if await router.handleMessage(prefix, msg): # Dont go through all the prefixes if one of them works
            return true

export parseutils
export strscans
