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
import sequtils
import segfaults
import macroUtils
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
        guildID: string
        case kind: CommandType
            of ctSlashCommand:
                slashHandler: SlashCommandProc
            of ctChatCommand:
                chatHandler: ChatCommandProc
                discard
    
    CommandHandler = ref object
        discord: DiscordClient
        msgVariable: string
        # TODO move from a table to a tree like structure. It will allow the user to declare command groups if they are in a tree
        chatCommands: Table[string, Command]
        slashCommands: Table[string, Command]

proc newHandler*(discord: DiscordClient, msgVariable: string = "msg"): CommandHandler =
    ## Creates a new handler which you can add commands to
    return CommandHandler(discord: discord, msgVariable: msgVariable)

proc getStrScanSymbol(typ: string): string =
    ## Gets the symbol that strscan uses in order to parse something of a certain type
    case typ:
        of "int": "$i"
        of "string": "$w"
        of "Channel": "#$w>"
        else: ""

proc scanfSkipToken*(input: string, start: int, token: string): int =
    ## Skips to the end of the first found token. The token can be found in the middle of a string e.g.
    ## The token `hello` can be found in foohelloworld
    ## Returns 0 if the token was not found
    var index = start
    template notWhitespace(): bool = not (input[index] in Whitespace)
    while index < input.len:
        if index < input.len and notWhitespace:
            let identStart = index
            for character in token: # See if each character in the token can be found in sequence 
                if input[index] == character:
                    inc index
            let ident = substr(input, identStart, index - 1)
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
        scanPattern &= getStrScanSymbol(parameter.kind) & "$s" # Add a space since the parameters are seperated by a space
        case parameter.kind:
            of "Channel":
                result.add parseExpr fmt"var {parameter.name}: string"
            else:
                result.add parseExpr fmt"var {parameter.name}: {parameter.kind}"
    scanPattern = scanPattern.strip()  # Remove final space so that it matches properly
    # Add in the scanning code
    var scanfCall = nnkCall.newTree(
        ident("scanf"),
        ident("msg").newDotExpr(ident("content")),
        newLit(scanPattern)
    )
    for parameter in parameters:
        scanfCall.add ident(parameter.name)
    result.add quote do:
        if `scanfCall`:
            `prc`
    echo result.toStrLit()

proc register*(router: CommandHandler, name: string, handler: ChatCommandProc) =
    router.chatCommands[name].chatHandler = handler


proc register*(router: CommandHandler, name: string, handler: SlashCommandProc) =
    router.slashCommands[name].slashHandler = handler

proc generateHelpMessage*(router: CommandHandler): Embed =
    ## Generates the help message for all the chat commands
    result.title = some "Help"
    result.fields = some newSeq[EmbedField]()
    result.description = some "Commands"
    for command in router.chatCommands.values:
        var body = command.description & ": "
        for parameter in command.parameters:
            body &= fmt"<{parameter.name}> "
        result.fields.get().add EmbedField(
            name: command.name,
            value: body,
            inline: some true
        )        
    echo result
macro addChat*(router: CommandHandler, name: static[string], handler: untyped): untyped =
    ## Add a new chat command to the handler
    ## A chat command is a command that the bot handles when it gets sent a message
    let 
        procName = newIdentNode(name & "Command") # The name of the proc that is returned 
        parameters = handler.getParameters()
        description = handler.getDoc()
        body = handler.body.addChatParameterParseCode(name, parameters)
        msgVariable = "msg".ident()
        cmdVariable = genSym(kind = nskVar, ident = "command")
    # router.chatCommands[name] = newCommand
    result = newStmtList()
    
    result.add quote do:
            var `cmdVariable` = Command(
                name: `name`,
                description: `description`,
                kind: ctChatCommand
            )
            echo `cmdVariable`
            

    if len(parameters) > 0:
        for parameter in parameters:
            result.add quote do:
                `cmdVariable`.parameters &= `parameter`

    result.add quote do:
        proc `procName`(`msgVariable`: Message) {.async.} =
            `body`

    result.add quote do:
        `cmdVariable`.chatHandler = `procName`
        `router`.chatCommands[`name`] = `cmdVariable`
    echo result.toStrLit()


proc getHandler(router: CommandHandler, name: string): ChatCommandProc =
    ## Returns the handler for a command with a certain name
    result = router.chatCommands[name].chatHandler

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
    if name == "help":
        discard await router.discord.api.sendMessage(msg.channelID, "", embed = some router.generateHelpMessage())

    if router.chatCommands.hasKey(name):
        let command = router.chatCommands[name]
        # TODO clean up this statement
        if command.guildID != "" and ((command.guildID != "" and msg.guildID.isSome()) and command.guildID != msg.guildID.get()):
            result = false
        else:
            await command.chatHandler(msg)
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
export sequtils