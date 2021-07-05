import dimscord
import compat
import std/[
    tables,
    macros,
    options,
    asyncdispatch
]
import discordUtils

type
    InteractionCommandData = Table[string, ApplicationCommandInteractionDataOption]
    InteractionScanner* = object # Keeps common vaApplicationCommandInteractionDatariables together and allows simpiler api
        iact: Interaction
        data: InteractionCommandData
        api: RestApi

template traverse(initData: ApplicationCommandInteractionData, onGroup: untyped): untyped {.dirty.} =
    var currentData = initData
    while true:
        var found = false
        for data in currentData.options.values:
            if data.kind == acotSubCommandGroup:
                onGroup
                found = true
            if data.kind == acotSubCommand:
                onGroup
        assert found, "This shouldn't happen, please put an issue on the github https://github.com/ire4ever1190/dimscmd"

proc getWords*(i: Interaction): seq[string] =
    var currentData = i.data.get()
    result &= currentData.name
    while true:
        var found = false
        for data in currentData.options.values:
            if data.kind == acotSubCommandGroup:
                result &= data.name
                found = true
            elif data.kind == acotSubCommand:
                result &= data.name
                return result
        if not found:
            break


proc getTail*(data: ApplicationCommandInteractionData): InteractionCommandData =
    ## Returns the tail end of the application data
    ## Also returns the full name of the sub command groups merged together
    result = data.options
    while true:
        var found = false
        for data in result.values:
            if data.kind == acotSubCommandGroup:
                result = data.options
                found = true
            elif data.kind == acotSubCommand: # There should only be one SubCommand in response
                return data.options
        if not found:
            break

proc newInteractionGetter*(i: Interaction, api: RestApi): InteractionScanner =
    InteractionScanner(
        iact: i,
        data: i.data.get().getTail(), # Can data even be null?
        api: api
    )

using scnr: InteractionScanner
##
## Getting data
##
template getOption(
        opts: Table[string, ApplicationCommandInteractionDataOption],
        kind: typedesc,
        key: string,
        prop: untyped): untyped {.dirty.} =
    bind hasKey
    bind `[]`
    block:
        if opts.hasKey(key):
            some opts[key].prop
        else:
            none kind

# Basic types
proc get*(scnr; kind: typedesc[int], key: string):    Option[int]    = scnr.data.getOption(int, key, ival)
proc get*(scnr; kind: typedesc[bool], key: string):   Option[bool]   = scnr.data.getOption(bool, key, bval)
proc get*(scnr; kind: typedesc[string], key: string): Option[string] = scnr.data.getOption(string, key, str)

proc get*[T: enum](scnr; kind: typedesc[T], key: string): Option[T] =
    let token = scnr.get(string, key)
    if token.isSome():
        for val in kind:
            if $val == token.get():
                return some val
    none kind

# Discord types
proc get*(scnr; kind: typedesc[User], key: string): Future[Option[User]] {.async.} =
    # let userID = scnr.get(string, key)
    let userID = scnr.data.getOption(string, key, userID)
    if userID.isSome():
        result = some await scnr.api.getUser(userID.get())
    else:
        result = none User

proc get*(scnr; kind: typedesc[Role], key: string): Future[Option[Role]] {.async.} =
    let roleID = scnr.data.getOption(string, key, roleID)
    if roleID.isSome():
        when libVer != "1.2.7":
            result = some await scnr.api.getGuildRole(scnr.iact.guildID, roleID.get())
        else:
            result = some await scnr.api.getGuildRole(scnr.iact.guildID.get(), roleID.get())

    else:
        result = none Role

proc get*(scnr; kind: typedesc[GuildChannel], key: string): Future[Option[GuildChannel]] {.async.} =
    let guildID = scnr.data.getOption(string, key, channelID)
    if guildID.isSome():
        result = some (await scnr.api.getChannel(guildID.get()))[0].get()
    else:
        result = none GuildChannel


##
## Adding data
##

# should be template
# macro newCmdBuilder(name: untyped, cmdType: ApplicationCommandOptionType): untyped =
#     # Used for the basic slash types (basically everything but enums)
#     # Generates a builder proc that is used to add another option to a command
#     result = quote do:
#         proc `name`(cmd: var ApplicationCommand, name, description: string, required = true) =
#             cmd.options &= ApplicationCommandOption(
#                 kind: ApplicationCommandOptionType(`cmdType`),
#                 name: name,
#                 description: description,
#                 required: some required
#             )
#
# proc newApplicationCommand(name, description: string): ApplicationCommand =
#   result = ApplicationCommand(
#         name: name,
#         description: description
#   )
#
#
# newCmdBuilder(addString, acotStr)
# newCmdBuilder(addInt, acotInt)
# newCmdBuilder(addBool, acotBool)
# newCmdBuilder(addUser, acotUser)
# newCmdBuilder(addRole, acotRole)
# newCmdBuilder(addGuildChannel, acotChannel)
export tables