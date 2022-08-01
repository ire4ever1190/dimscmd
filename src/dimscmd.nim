import macros
import strutils
import parseutils
import strformat, strutils
import asyncdispatch
import dimscord
import std/[
    sugar,
    options,
    strscans,
    tables,
    sequtils
]
import dimscmd/[
    macroUtils,
    commandOptions,
    scanner,
    common,
    discordUtils,
    interactionUtils,
    utils
]
{.experimental: "dynamicBindSym".}

proc defaultHelpMessage*(m: Message, handler: CommandHandler, commandName: string) {.async.} =
    ## Generates the help message for all the chat commands
    var embed = Embed()
    if commandName == "":
        embed.title = some "Commands list"
        embed.fields = some newSeq[EmbedField]()
        var description = "Run the help command again followed by a command name to get more info\n"
        for command in handler.chatCommands.flatten():
            if command.names.len > 1:
                var aliasesList: seq[string]
                for alias in command.aliases:
                    aliasesList &= fmt"`{alias}`"

                description &= fmt"`{command.name} or (" &  aliasesList.join(", ") & ")"
            else:
                description &= fmt"`{command.name}`, "
        embed.description = some description
    else:
        if not handler.chatCommands.has(commandName.getWords()):
            discard await handler.discord.api.sendMessage(m.channelID, "There is no command named " & commandName)
        else:
            let group = handler.chatCommands.getGroup(commandName.getWords())
            if group.isLeaf:
                let command = group.command
                embed.title = some command.name
                var description = command.description & "\n"
                description &= "**Usage**\n"
                description &= command.name
                for parameter in command.parameters:
                    description &= fmt" <{parameter.name}>"
                embed.description = some description
            else:
                embed.title = some group.name
                var description = "**Top level sub commands belonging to this group**\n"
                for child in group.children:
                    description &= child.name & "\n"
                embed.description = some description
    if embed.title.isSome(): # title is only empty when it couldn't find a command
        discard await handler.discord.api.sendMessage(m.channelID, "", embeds = @[embed])

proc newHandler*(discord: DiscordClient, msgVariable: string = "msg"): CommandHandler =
    ## Creates a new handler which you can add commands to
    return CommandHandler(
        discord: discord,
        msgVariable: msgVariable,
        chatCommands: newGroup("", ""),
        slashCommands: newGroup("", "")
    )

proc getScannerCall*(parameter: ProcParameter, scanner: NimNode, getInner = false): NimNode =
    ## Construct a call but adding the needed generic types to the `kind` variable
    ## and then generating a call for `next` which takes the current scanner and the type.
    ## The corresponding `next` call will be looked up by Nim, this allows for easier creation of new types
    ## and also allows user created types
    var kind = parameter.kind.ident()
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
    ## This injects code to the start of a block of code which will parse cmdInput and set the variables for the different parameters.
    ## The calls to get parameters from the scanner can be user defined for custom types, check scanner.nim
    ## for details on how to implement your own
    
    if len(parameters) == 0: return prc # Don't inject code if there is nothing to scan
    result = newStmtList()
    let scannerIdent = genSym(kind = nskLet, ident = "scanner")
    # Start the scanner and skip past the command
    result.add quote do:
        bind leafName
        let `scannerIdent` = `router`.discord.api.newScanner(`msgName`)
        # We need to check every alias to see what we need to skip past
        let cmdNames = block:
            var names: seq[string]
            for name in `router`.chatCommands.get(`name`.split(" ")).names:
                names &= name.getWords[^1]
            names
        `scannerIdent`.skipPast(cmdNames)

    for parameter in parameters:
        if parameter.kind == "message": continue
        let ident = parameter.name.ident()
        let scanCall = getScannerCall(parameter, scannerIdent)
        result.add quote do:
            let `ident` = `scanCall`

    result = quote do:
        `result`
        `prc`

proc addInteractionParameterParseCode(prc: NimNode, name: string, parameters: seq[ProcParameter], iName: NimNode, router: NimNode): NimNode =
    ## Adds code into the proc body to get all the variables from the Interaction event
    let scannerIdent = genSym(kind = nskLet, ident = "scanner")
    result = newStmtList()
    result.add quote do:
        let `scannerIdent` = newInteractionGetter(`iName`, `router`.discord.api)

    for parameter in parameters:
        let ident = parameter.name.ident()
        var procCall = nnkCall.newTree(
            "get".bindSym(brOpen),
            scannerIdent,
            parameter.kind.ident(),
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

# I don't know where these are used but I'm afraid to remove them
proc register*(router: CommandHandler, name: string, handler: ChatCommandProc) =
    router.chatCommands.get(name.getWords()).chatHandler = handler

proc register*(router: CommandHandler, name: string, handler: SlashCommandProc) =
    router.slashCommands.get(name.getWords()).slashHandler = handler

macro addCommand(router: untyped, name: static[string], handler: untyped, kind: static[CommandType],
                guildID: string, params: varargs[typed]): untyped =
    ## This is the internal macro which creates the command variable and maps it to the command router
    ## It goes through these steps
    ##  - Get info like name, description
    ##  - Insert a variable into the calling scope with that info
    ##  - Go through each parameter and
    ##      - See if it is replacing the default `msg` or `i` variable
    ##      - Check that optional parameters are only at the end if it's a slash command
    ##      - Add those parameters to the command variable created before
    ##  - Insert a proc that takes two parameters shard and also Message or Interaction
    ##      - This proc has the parsing code insert before the user code which creates variables
    ##        corresponding to the user specified parameters
    ##  - Add the proc to the command variable and then map the command to the router
    let 
        procName = newIdentNode(name & "Command") # The name of the proc that is returned is the commands name followed by "Command"
        cmdVariable = genSym(kind = nskVar, ident = "command")

    let description = handler.getDoc()
      
    if kind == ctSlashCommand and description.isEmptyOrWhitespace:
      "Must provide a description has a doc comment".error(handler)
      
        
    result = newStmtList()
    result.add quote do:
        var `cmdVariable` = Command(
            names: @[`name`],
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
        let
            parameterIdent = parameter.name.ident()
            parameterConstr = parameter.newLit()
        # Add a check that an optional slash is at the end
        if kind == ctSlashCommand and mustBeOptional and not parameter.optional:
            fmt"Optional parameters must be at the end".error(handler.params[paramIndex])
        mustBeOptional = parameter.optional or mustBeOptional # Once its true it stays true
        # Check the kind to see if it can be used has an alternate variable for the Message or Interaction
        matchIdent(parameter.kind):
            "Message":     msgVariable         = parameterIdent
            "Interaction": interactionVariable = parameterIdent
            "Shard":       shardVariable       = parameterIdent
            else:
                parameters &= parameter
                result.add quote do:
                    `cmdVariable`.parameters &= `parameterConstr`
        inc paramIndex
    case kind:
        of ctChatCommand:
            let body = handler.addChatParameterParseCode(name, parameters, msgVariable, router)
            result.add quote do:
                proc `procName`(`shardVariable`: Shard, `msgVariable`: Message) {.async.} =
                    `body`

                `cmdVariable`.chatHandler = `procName`
                `router`.chatCommands.map(`cmdVariable`)

        of ctSlashCommand:
            let body = handler.addInteractionParameterParseCode(name, parameters, interactionVariable, router)
            result.add quote do:
                proc `procName`(`shardVariable`: Shard, `interactionVariable`: Interaction) {.async.} =
                    `body`

                `cmdVariable`.slashHandler = `procName`
                `router`.slashCommands.map(`cmdVariable`)

macro addChat*(router: CommandHandler, name: string, handler: untyped): untyped =
    ## Add a new chat command to the handler
    ## A chat command is a command that the bot handles when it gets sent a message
    ##
    ## .. code-block:: nim
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
    ## .. code-block:: nim
    ##
    ##    cmd.addSlash("hello") do ():
    ##        ## I echo hello to the console
    ##        echo "hello world"
    ##
    ##    # Can also be made to only run in a certain guild
    ##    cmd.addSlash("hello", guildID = "123456789") do ():
    ##        ## I echo hello to the console
    ##        echo "Hello world"
    # This doesn't actually do the processessing to add the call since the parameters need to be typed first
    var
        handler: NimNode = nil
        guildID: NimNode = newStrLitNode("")
    # TODO, make this system be cleaner
    # Think I can wait for that nim PR to be merged to solve this
    for arg in parameters:
        case arg.kind:
            of nnkDo:
                handler = arg
            of nnkExprEqExpr:
                matchIdent(arg[0].strVal()):
                    "guildID":
                        guildID = arg[1]
                    else:
                        raise newException(ValueError, "Unknown parameter " & arg[0].strVal)
            else:
                raise newException(ValueError, "Unknown node of kind" & $arg.kind)
    if handler == nil: # Don't know how this could happen
        error("You have not specified a handler using do syntax")

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

proc addAlias*(group: CommandGroup, commandName: string, aliases: openArray[string]) =
  ## Like addChatAlias_ or addSlashAlias_ except more generic
  runnableExamples "-r:off --threads:off":
    import dimscord
    let cmd = newDiscordClient("TOKEN").newHandler()
    # Alias can be added like so
    cmd.chatCommands.addAlias("ping", ["pi"])
    cmd.slashCommands.addAlias("joke", ["funnyword"])
  #==#
  # TODO: link to docs about requirements
  let commandKey = commandName.getWords()
  if group.has(commandKey):
    var command = group.get(commandKey)
    for alias in aliases:
      command.names &= alias
      group.mapAltPath(commandKey, alias.split(" "))
  else:
    raise newException(KeyError, fmt"Cannot find command {commandName} to alias")

proc addChatAlias*(router: CommandHandler, commandName: string, aliases: openArray[string]) =
  ## Adds alternate names for a chat command command
  runnableExamples "-r:off --threads:off":
    import dimscord
    let cmd = newDiscordClient("TOKEN").newHandler()
    # Allow the user to use `pingy` or `pin` to refer to the `ping` command 
    cmd.addChatAlias("ping", ["pingy", "pin"])
  #==#
  router.chatCommands.addAlias(commandName, aliases)

proc addSlashAlias*(router: CommandHandler, commandName: string, aliases: openArray[string]) =
  ## Works like addChatAlias_ except it makes the alias for a slash command instead
  router.slashCommands.addAlias(commandName, aliases)

proc registerCommands*(handler: CommandHandler) {.async.} =
    ## Registers all the slash commands with discord.
    ## This handles updating new command and removing old commands but it will
    ## leave old commands in a guild if you specifically add them to certain guilds
    ## and then remove those commands from your code.
    ##
    ## .. code-block:: nim
    ##
    ##  proc onReady (s: Shard, r: Ready) {.event(discord).} =
    ##      await cmd.registerCommands()
    ##
    ## note: If you have a command group then the guildID will be choosen from the first command
    let api = handler.discord.api
    handler.applicationID = (await api.getCurrentApplication()).id  # Get the bots application ID
    var commands: Table[string, seq[ApplicationCommand]]
    # Convert everything from internal Command type to discord ApplicationCommand type
    for child in handler.slashCommands.children:
        let guildID = child.getGuildID()
        discard commands.hasKeyOrPut(guildID, @[])
        commands[guildID] &= child.toApplicationCommand()
    # Add the commands to their specific guilds
    for guildID, cmds in commands.pairs():
        discard await api.bulkOverwriteApplicationCommands(handler.applicationID, cmds, guildID = guildID)

proc handleMessage*(handler: CommandHandler, prefix: string, s: Shard, msg: Message): Future[bool] {.async.} =
    ## Handles an incoming discord message and executes a command if necessary.
    ## This returns true if a command was found
    ## 
    ## .. code-block:: nim
    ## 
    ##    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    ##        discard await cmd.handleMessage("$$", msg)
    ##
    if not msg.content.startsWith(prefix): return
    let content = msg.content
    var offset = len(prefix)
    offset += content.skipWhitespace(start = offset)
    var currentNode = handler.chatCommands
    while not currentNode.isLeaf:
        var name: string
        offset += content.nextWord(name, start = offset)
        var foundCommand = false
        for node in currentNode.children:
            # Break out of the for loop if a matching child is found
            if name == node.name:
                currentNode = node
                foundCommand = true
                break
        if not foundCommand and name == "help":
            let commandName = content[offset..^1]
            await defaultHelpMessage(msg, handler, commandName)
            return true

        elif not foundCommand:
            # End function here if a command could not be found
            return false
    # If a command is not found then a `return` statement is used, not a break
    # so we now that we have found a command at this stage
    let command = currentNode.command
    try:
        await command.chatHandler(s, msg)
        result = true
    except ScannerError as e:
        when defined(debug) and not defined(testing):
            echo e.message
        discard await handler.discord.api.sendMessage(msg.channelID, e.message)

proc handleMessage*(router: CommandHandler, prefix: string, msg: Message): Future[bool] {.async, deprecated: "Pass the shard parameter before msg".} =
    result = await handleMessage(router, prefix, nil, msg)


proc handleInteraction*(router: CommandHandler, s: Shard, i: Interaction): Future[bool] {.async.}=
    ## Handles an incoming interaction from discord which is needed for slash commands to work.
    ## Returns true if a slash command was found and run
    ##
    ## .. code-block:: nim
    ##
    ##  proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
    ##      discard await cmd.handleInteraction(s, i)
    ##
    let commandName = i.data.get().name
    var currentData = i.data.get()
    let interactionHandlePath = i.getWords()
    if router.slashCommands.has(interactionHandlePath): # It should, but best to check
      let command = router.slashCommands.get(interactionHandlePath)
      await command.slashHandler(s, i)
      result = true

proc handleMessage*(router: CommandHandler, prefixes: seq[string], s: Shard, msg: Message): Future[bool] {.async.} =
    ## Handles an incoming discord message and executes a command if necessary.
    ## This returns true if a command was found and executed. It will return once a prefix is correctly found
    ## 
    ## .. code-block:: nim
    ## 
    ##    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    ##        discard await cmd.handleMessage(["$$", "&"], msg) # Both $$ and & prefixes will be accepted
    ##
    for prefix in prefixes:
        if await router.handleMessage(prefix, s, msg): # Dont go through all the prefixes if one of them works
            return true

proc handleMessage*(router: CommandHandler, prefixes: seq[string], msg: Message): Future[bool] {.async, deprecated: "Pass the shard parameter before msg".} =
    result = await handleMessage(router, prefixes, nil, msg)

export parseutils
export strscans
export skipPast # Code doesn't seem to be able to bind this
export sequtils
export utils
export tables
