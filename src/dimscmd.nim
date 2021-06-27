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
    group,
    commandOptions,
    scanner,
    common,
    discordUtils,
    compat,
    interactionUtils,
    utils
]
# TODO, learn to write better documentation

proc defaultHelpMessage*(m: Message, handler: CommandHandler, commandName: string) {.async.} =
    ## Generates the help message for all the chat commands
    var embed = Embed()
    if commandName == "":
        embed.title = some "Commands list"
        embed.fields = some newSeq[EmbedField]()
        var description = "Run the help command again followed by a command name to get more info\n"
        # TODO, group commands into groups
        for command in handler.chatCommands.flatten():
            description &= fmt"`{command.groupName}`, "
        embed.description = some description
    else:
        if not handler.chatCommands.has(commandName.getWords()):
            discard await handler.discord.api.sendMessage(m.channelID, "There is no command named " & commandName)
        else:
            let command = handler.chatCommands.get(commandName.getWords())
            embed.title = some command.name
            var description = command.description & "\n"
            description &= "**Usage**\n"
            description &= command.name
            for parameter in command.parameters:
                description &= fmt" <{parameter.name}>"
            embed.description = some description
    if embed.title.isSome(): # title is only empty when it couldn't find a command
        discard await handler.discord.api.sendMessage(m.channelID, "", embed = some embed)

proc newHandler*(discord: DiscordClient, msgVariable: string = "msg"): CommandHandler =
    ## Creates a new handler which you can add commands to
    return CommandHandler(
        discord: discord,
        msgVariable: msgVariable,
        chatCommands: newGroup("", ""),
        slashCommands: newGroup("", "")
    )

proc getScannerCall*(parameter: ProcParameter, scanner: NimNode, getInner = false): NimNode =
    ## Generates the call needed to scan a parameter. This is done by constructing the call
    ## as a string and the parsing it with parseExpr()
    var kind = parameter.originalKind.ident()
    if parameter.sequence:
        kind = nnkBracketExpr.newTree("seq".ident(), kind)
    if parameter.optional:
        kind = nnkBracketExpr.newTree("Option".ident(), kind)
    if parameter.future:
        kind = nnkBracketExpr.newTree("Future".ident(), kind)
    result = newCall(
            "next".bindSym(brOpen),
            scanner,
            kind
        )
    if parameter.future:
        result = nnkCommand.newTree("await".ident(), result)

proc addChatParameterParseCode(prc: NimNode, name: string, parameters: seq[ProcParameter], msgName: NimNode, router: NimNode): NimNode =
    ## This injects code to the start of a block of code which will parse cmdInput and set the variables for the different parameters
    ## Currently it only supports int and string parameter types
    ## This is achieved with the strscans module
    
    if len(parameters) == 0: return prc # Don't inject code if there is nothing to scan
    result = newStmtList()
    let scannerIdent = genSym(kind = nskLet, ident = "scanner")
    # Start the scanner and skip past the command
    result.add quote do:
        bind leafName
        let `scannerIdent` = `router`.discord.api.newScanner(`msgName`)
        `scannerIdent`.skipPast(`name`.leafName())

    for parameter in parameters:
        if parameter.kind == "message": continue
        let ident = parameter.name.ident()
        let scanCall = getScannerCall(parameter, scannerIdent)
        result.add quote do:
            let `ident` = `scanCall`

    result = quote do:
        `result`
        `prc`

{.experimental: "dynamicBindSym".}
proc addInteractionParameterParseCode(prc: NimNode, name: string, parameters: seq[ProcParameter], iName: NimNode, router: NimNode): NimNode =
    ## Adds code into the proc body to get all the variables
    let scannerIdent = genSym(kind = nskLet, ident = "scanner")
    result = newStmtList()
    result.add quote do:
        let `scannerIdent` = newInteractionGetter(`iName`, `router`.discord.api)

    for parameter in parameters:
        let ident = parameter.name.ident()
        var procCall = nnkCall.newTree(
            "get".bindSym(brOpen),
            scannerIdent,
            parameter.originalKind.ident(),
            parameter.name.newStrLitNode()
        )
        if parameter.future:
            procCall = nnkCommand.newTree("await".ident(), procCall)

        if not parameter.optional:
            # If the parameter isn't optional then make sure the variable is not an optional type
            procCall = nnkCall.newTree("get".ident(), procCall)

        result.add quote do:
            let `ident` = `procCall`
    result.add prc


proc register*(router: CommandHandler, name: string, handler: ChatCommandProc) =
    router.chatCommands.get(name.getWords()).chatHandler = handler


proc register*(router: CommandHandler, name: string, handler: SlashCommandProc) =
    router.slashCommands.get(name.getWords()).slashHandler = handler

macro addCommand(router: untyped, name: static[string], handler: untyped, kind: static[CommandType],
                guildID: string, params: varargs[typed]): untyped =
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
        msgVariable         = "msg".ident()
        interactionVariable = "i".ident()
        shardVariable       = "s".ident()

    #
    # Get all the parameters that the command has and check whether it will get parsed from the message or it is it the message
    # itself
    #
    var
        parameters: seq[ProcParameter]
        mustBeOptional = false
        paramIndex = 0
    for parameter in params.getParameters():
        # Check the kind to see if it can be used has an alternate variable for the Message or Interaction
        let parameterIdent = parameter.name.ident()
        # Add a check that an optional slash is at the end
        if kind == ctSlashCommand and mustBeOptional and not parameter.optional:
            fmt"Optional parameters must be at the end".error(handler.params[paramIndex])
        mustBeOptional = parameter.optional or mustBeOptional # Once its true it stays true
        case parameter.kind:
            of "message":     msgVariable         = parameterIdent
            of "interaction": interactionVariable = parameterIdent
            of "shard":       shardVariable       = parameterIdent
            else:
                parameters &= parameter
                result.add quote do:
                    `cmdVariable`.parameters &= `parameter`
        inc paramIndex
    case kind:
        of ctChatCommand:
            let body = handler.addChatParameterParseCode(name, parameters, msgVariable, router)
            result.add quote do:
                proc `procName`(`shardVariable`: Shard, `msgVariable`: Message) {.async.} =
                    `body`

                `cmdVariable`.chatHandler = `procName`
                `router`.chatCommands.map(`name`.toKey(), `cmdVariable`)

        of ctSlashCommand:
            let body = handler.addInteractionParameterParseCode(name, parameters, interactionVariable, router)
            result.add quote do:
                proc `procName`(`shardVariable`: Shard, `interactionVariable`: Interaction) {.async.} =
                    `body`
                `cmdVariable`.slashHandler = `procName`
                `router`.slashCommands.map(`name`.toKey(), `cmdVariable`)

macro addChat*(router: CommandHandler, name: string, handler: untyped): untyped =
    ## Add a new chat command to the handler
    ## A chat command is a command that the bot handles when it gets sent a message
    ## ..code-block:: nim
    ##
    ##    cmd.addChat("ping") do ():
    ##        discord.api.sendMessage(msg.channelID, "pong")
    ##

    result = nnkCall.newTree(
        "addCommand".bindSym(),
        router,
        name,
        handler.body(),
        "ctChatCommand".bindSym(),
        "".newStrLitNode()
    )
    for param in handler.getParamTypes():
        result &= param

macro addSlash*(router: CommandHandler, name: string, parameters: varargs[untyped]): untyped =
    ## Add a new slash command to the handler
    ## A slash command is a command that the bot handles when the user uses slash commands
    ## 
    ## ..code-block:: nim
    ##
    ##    cmd.addSlash("hello") do ():
    ##        ## I echo hello to the console
    ##        echo "hello world"
    ##
    ##    # Can also be made to only run in a certain guild
    ##    cmd.addSlash("hello", guildID = "123456789') do ():
    ##        ## I echo hello to the console
    ##        echo "Hello world"
    # This doesn't actually do the processessing to add the call since the parameters need to be typed first

    var
        handler: NimNode = nil
        guildID: NimNode = newStrLitNode("")
    # TODO, make this system be cleaner
    for arg in parameters:
        case arg.kind:
            of nnkDo:
                handler = arg
            of nnkExprEqExpr:
                case arg[0].strVal.toLowerAscii().replace("_", ""):
                    of "guildid":
                        guildID = arg[1]
                    else:
                        raise newException(ValueError, "Unknown parameter " & arg[0].strVal)
            else:
                raise newException(ValueError, "Unknown node of kind" & $arg.kind)
    if handler == nil: # Don't know how this could happen
        error("You have not specified a handler using do syntax")

    for char in name.strVal():
        if not(char.isLowerAscii() or char == '-'):
            error("Slash command names must be lower case (use kebab-case for notation if needed)", name)
    if handler.body().getDoc() == "":
        error("Please add a doc comment to this explaining what it does", parameters[^1])
    # Pass in a macro call which gets typed value so that it binds in the scope of the caller
    result = nnkCall.newTree(
            "addCommand".bindSym(),
            router,
            name,
            handler.body(),
            "ctSlashCommand".bindSym(),
            guildID
        )
    for param in handler.getParamTypes():
        result &= param



proc registerCommands*(handler: CommandHandler) {.async.} =
    ## Registers all the slash commands with discord
    let api = handler.discord.api
    handler.applicationID = (await api.getCurrentApplication()).id  # Get the bots application ID
    var commands: Table[string, seq[ApplicationCommand]] # Split the commands into their guilds
    # Convert everything from internal Command type to discord ApplicationCommand type
    for leaf in handler.slashCommands.flatten():
        let command = leaf.cmd
        let guildID = command.guildID
        if not commands.hasKey(guildID):
            commands[guildID] = newSeq[ApplicationCommand]()
        commands[guildID] &= command.toApplicationCommand()

    for guildID, cmds in commands.pairs():
        discard await api.bulkOverwriteApplicationCommands(handler.applicationID, cmds, guildID = guildID)

proc handleMessage*(handler: CommandHandler, prefix: string, s: Shard, msg: Message): Future[bool] {.async.} =
    ## Handles an incoming discord message and executes a command if necessary.
    ## This returns true if a command was found
    ## 
    ## ..code-block:: nim
    ## 
    ##    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    ##        discard await cmd.handleMessage("$$", msg)
    ##     
    if not msg.content.startsWith(prefix): return # There wont be any spaces at the start
    let content = msg.content
    var offset = prefix.len + content.skipWhitespace(prefix.len)

    var
        currentNode = handler.chatCommands
        findingCommand = true

    while findingCommand:
        var name: string
        offset += content.parseUntil(name, start = offset, until = Whitespace)
        offset += content.skipWhitespace(start = offset)
        # Go through all children to see if there is a matching group
        for node in currentNode.children:
            if node.name == name:
                currentNode = node
                break
        # Check if the group is actually a command
        if currentNode.isLeaf:
            findingCommand = false
            let command = currentNode.command
            try:
                await command.chatHandler(s, msg)
                result = true
            except ScannerError as e:
                when defined(debug) and not defined(testing):
                    echo e.message
                discard await handler.discord.api.sendMessage(msg.channelID, e.message)
            break

        elif name == "help":
            ## TODO make help more ergonomic
            findingCommand = false
            var commandName: string
            offset += content.skipWhitespace(offset + 4) # 4 characters in help
            discard content.parseUntil(commandName, start = offset, until = Whitespace)
            echo commandName
            await defaultHelpMessage(msg, handler, commandName)
            result = true

proc handleMessage*(router: CommandHandler, prefix: string, msg: Message): Future[bool] {.async, deprecated: "Pass the shard parameter before msg".} =
    result = await handleMessage(router, prefix, nil, msg)

proc handleInteraction*(router: CommandHandler, s: Shard, i: Interaction): Future[bool] {.async.}=
    let commandName = i.data.get().name
    if router.slashCommands.has(commandName.getWords()):
        let command = router.slashCommands.get(commandName.getWords())
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
export skipPast # Code doesn't seem to be able to bind this
export sequtils
export utils
export compat
export group