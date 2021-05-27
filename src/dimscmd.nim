import macros
import strutils
import parseutils
import strformat, strutils
import asyncdispatch
import strscans
import options
import dimscord
import tables
import sequtils
import segfaults
import dimscmd/[
    macroUtils,
    commandOptions,
    scanner,
    common,
    discordUtils
]
# TODO, see if you can move from untyped to typed?
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

var dimscordDefaultGuildID* = ""

proc newHandler*(discord: DiscordClient, msgVariable: string = "msg"): CommandHandler =
    ## Creates a new handler which you can add commands to
    return CommandHandler(discord: discord, msgVariable: msgVariable)

proc getScannerCall*(parameter: ProcParameter, scanner: NimNode, getInner = false): NimNode =
    ## Generates the call needed to scan a parameter
    let procName = case parameter.kind:
        of "channel", "guildchannel": "nextChannel"
        of "user": "nextUser"
        of "role": "nextRole"
        of "int": "nextInt"
        of "string": "nextString"
        of "bool": "nextBool"
        else: ""
    if (parameter.sequence or parameter.optional) and not getInner:
        var innerCall = getScannerCall(parameter, scanner, true)
        if innerCall[0] == "await".ident: # vomit emoji TODO do better
            innerCall[0] = innerCall[1][0]
        let callIdent = ident(if parameter.sequence: "nextSeq" else: "nextOptional")
        result = newCall(callIdent.ident, scanner, innerCall[0])

    else:
        result = newCall(procName, scanner)

    if parameter.kind in ["channel", "user", "role"]:
        result = nnkCommand.newTree("await".ident, result)

proc addChatParameterParseCode(prc: NimNode, name: string, parameters: seq[ProcParameter], msgName: NimNode, router: NimNode): NimNode =
    ## **INTERNAL**
    ## This injects code to the start of a block of code which will parse cmdInput and set the variables for the different parameters
    ## Currently it only supports int and string parameter types
    ## This is achieved with the strscans module
    
    if len(parameters) == 0: return prc # Don't inject code if there is nothing to scan
    result = newStmtList()
    let scannerIdent = genSym(kind = nskLet, ident = "scanner")
    # Start the scanner and skip past the command
    result.add quote do:
        let `scannerIdent` = `router`.discord.api.newScanner(`msgName`)
        `scannerIdent`.skipPast(`name`)

    for parameter in parameters:
        if parameter.kind == "message": continue
        let ident = parameter.name.ident()
        let scanCall = getScannerCall(parameter, scannerIdent)
        result.add quote do:
            let `ident` = `scanCall`

    result = quote do:
        try:
            `result`
            `prc`
        except ScannerError as e:
            let msgParts = ($e.msg).split("(-)") # split so that async stack trace is not shown
            when defined(debug) and not defined(testing):
                echo e.msg
            discard await `router`.discord.api.sendMessage(`msgName`.channelID, msgParts[0])

proc addInteractionParameterParseCode(prc: NimNode, name: string, parameters: seq[ProcParameter], iName: NimNode, router: NimNode): NimNode =
    ## **INTERNAL**
    ## Adds code into the proc body to get all the variables
    result = newStmtList()
    var optionsIdent = genSym(kind = nskLet, ident = "options")
    result.add quote do:
        let `optionsIdent` = `iName`.data.get().options

    for parameter in parameters:
        let ident = parameter.name.ident()
        let paramName = parameter.name

        let attributeName = case parameter.kind:
            of "int": "ival"
            of "bool": "bval"
            of "string", "user", "channel", "role": "str"
            else: raise newException(ValueError, parameter.kind & " is not supported")
        let attributeIdent = attributeName.ident()

        if parameter.kind notin ["user", "role", "channel"]:
            if parameter.optional:
               result.add quote do:
                   let `ident` = `optionsIdent`[`paramName`].`attributeIdent`
            else:
                result.add quote do:
                    let `ident` = `optionsIdent`[`paramName`].`attributeIdent`.get()
        else:
            let idIdent = genSym(kind = nskLet, ident = "id")
            # TODO clean this up and make it more generic
            result.add quote do:
                let `idIdent` = `optionsIdent`[`paramName`].`attributeIdent`
            var callCode = newStmtList()
            case parameter.kind:
                of "user":
                    callCode = quote do:
                        await `router`.discord.api.getUser(`idIdent`.get())
                of "role":
                    callCode = quote do:
                        await `router`.discord.api.getGuildRole(`iName`.guildID.get(), `idIdent`.get())
                of "channel":
                    callCode = quote do:
                        (await `router`.discord.api.getChannel(`idIdent`.get()))[0].get()

            let paramType = ident(parameter.originalKind)
            if parameter.optional:
                result.add quote do:
                    let `ident` = if `idIdent`.isSome():
                        some `callCode`
                    else:
                        none `paramType`
            else:
                result.add quote do:
                    let `ident` = `callCode`
    result.add prc
    echo $result.toStrLit()


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


proc addCommand(router: NimNode, name: string, handler: NimNode, kind: CommandType): NimNode =
    handler.expectKind(nnkDo)
    # Create variables for optional parameters
    var
        guildID: NimNode = newStrLitNode("") # NimNode is used instead of string so that variables can be used
    
    var handlerBody = handler.body.copy() # Create a copy that can be edited without ruining the value that we are looping over
    for index, node in handler[^1].pairs():
        # TODO Remove this and change it to a pragma system or something
        if node.kind == nnkCommentStmt: continue # Ignore comments
        if node.kind == nnkCall:
            if node[0].kind != nnkIdent: break # If it doesn't contain an identifier then it isn't a config option
            case node[0].strVal.toLowerAscii() # Get the ident node
                of "guildid":
                    guildID = node[1][0]
                else:
                    # Extra parameters should be declared directly before or after the doc comment
                    break
            handlerBody.del(index)
                
   
    let 
        procName = newIdentNode(name & "Command") # The name of the proc that is returned is the commands name followed by "Command"
        description = handler.getDoc()
        cmdVariable = genSym(kind = nskVar, ident = "command")
    if kind == ctSlashCommand:
        doAssert description.len != 0, "Slash commands must have a description"
    result = newStmtList()
    
    result.add quote do:
            var `cmdVariable` = Command(
                name: `name`,
                description: `description`,
                guildID: `guildID`,
                kind: CommandType(`kind`)
            )

    # Default proc parameter names for msg and interaction            
    var 
        msgVariable = "msg".ident()
        interactionVariable = "i".ident()
        shardVariable = "s".ident()

    #
    # Get all the parameters that the command has and check whether it will get parsed from the message or it is it the message
    # itself
    #
    var parameters: seq[ProcParameter]
    for parameter in handler.getParameters():
        # Check the kind to see if it can be used has an alternate variable for the Message or Interaction
        case parameter.kind:
            of "message":
                msgVariable = parameter.name.ident()
            of "interaction":
                interactionVariable = parameter.name.ident()
            of "shard":
                shardVariable = parameter.name.ident()
            else:
                parameters &= parameter
                result.add quote do:
                    `cmdVariable`.parameters &= `parameter`
    # TODO remove code duplication?
    case kind:
        of ctChatCommand:
            let body = handlerBody.addChatParameterParseCode(name, parameters, msgVariable, router)
            result.add quote do:
                proc `procName`(`shardVariable`: Shard, `msgVariable`: Message) {.async.} =
                    `body`

                `cmdVariable`.chatHandler = `procName`
                `router`.chatCommands[`name`] = `cmdVariable`

        of ctSlashCommand:
            let body = handlerBody.addInteractionParameterParseCode(name, parameters, interactionVariable, router)
            result.add quote do:
                proc `procName`(`shardVariable`: Shard, `interactionVariable`: Interaction) {.async.} =
                    `body`
                `cmdVariable`.slashHandler = `procName` 
                `router`.slashCommands[`name`] = `cmdVariable`

macro addChat*(router: CommandHandler, name: static[string], handler: untyped): untyped =
    ## Add a new chat command to the handler
    ## A chat command is a command that the bot handles when it gets sent a message
    ## ..code-block:: nim
    ##
    ##    cmd.addChat("ping") do ():
    ##        discord.api.sendMessage(msg.channelID, "pong")
    ##
    result = addCommand(router, name, handler, ctChatCommand)

macro addSlash*(router: CommandHandler, name: static[string], handler: untyped): untyped =
    ## Add a new slash command to the handler
    ## A slash command is a command that the bot handles when the user uses slash commands
    ## 
    ## ..code-block:: nim
    ##    
    ##    cmd.addSlash("hello") do ():
    ##        ## I echo hello to the console
    ##        guildID: 1234567890 # Only add the command to a certain guild
    ##        echo "Hello world"
    result = addCommand(router, name, handler, ctSlashCommand)

proc getHandler(router: CommandHandler, name: string): ChatCommandProc =
    ## Returns the handler for a command with a certain name
    result = router.chatCommands[name].chatHandler

# proc toCommand(command: ApplicationCommand): Command =
#     result = Command(
#         name: command.name,
#         description: command.description
#     )

proc registerCommands*(handler: CommandHandler) {.async.} =
    ## Registers all the slash commands with discord
    # Get the bots application ID
    handler.applicationID = (await handler.discord.api.getCurrentApplication()).id
    var commands: seq[ApplicationCommand]
    for command in handler.slashCommands.values:
        commands &= command.toApplicationCommand()
    # Make guildID some kind of user defineable variable
    # that way debug builds automatically target a specific guild while prod builds are global
    {.gcsafe.}:
        discard await handler.discord.api.bulkOverwriteApplicationCommands(handler.applicationID, commands, guildID = dimscordDefaultGuildID)

proc handleMessage*(router: CommandHandler, prefix: string, s: Shard, msg: Message): Future[bool] {.async.} =
    ## Handles an incoming discord message and executes a command if necessary.
    ## This returns true if a command was found
    ## 
    ## ..code-block:: nim
    ## 
    ##    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    ##        discard await router.handleMessage("$$", msg)
    ##     
    if not msg.content.startsWith(prefix): return
    let content = msg.content
    let startWhitespaceLength = skipWhitespace(msg.content, len(prefix))
    var name: string
    discard parseUntil(content, name, start = len(prefix) + startWhitespaceLength, until = Whitespace)
    if name == "help":
        discard await router.discord.api.sendMessage(msg.channelID, "", embed = some router.generateHelpMessage())
        result = true

    elif router.chatCommands.hasKey(name):
        let command = router.chatCommands[name]
        # TODO clean up this statement
        if command.guildID != "" and ((command.guildID != "" and msg.guildID.isSome()) and command.guildID != msg.guildID.get()):
            result = false
        else:
            await command.chatHandler(s, msg)
            result = true

proc handleMessage*(router: CommandHandler, prefix: string, msg: Message): Future[bool] {.async, deprecated: "Pass the shard parameter before msg".} =
    result = await handleMessage(router, prefix, nil, msg)

proc handleInteraction*(router: CommandHandler, s: Shard, i: Interaction): Future[bool] {.async.}=
    let commandName = i.data.get().name
    # TODO add sub commands
    # TODO add guild specific slash commands
    if router.slashCommands.hasKey(commandName):
        let command = router.slashCommands[commandName]
        await command.slashHandler(s, i)
        result = true

proc handleMessage*(router: CommandHandler, prefixes: seq[string], msg: Message): Future[bool] {.async.} =
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
export scanner
export getGuildRole