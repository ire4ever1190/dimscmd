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
    InteractionScanner* = object # Keeps common variables together and allows simpiler api
        iact: Interaction
        api: RestApi

proc newInteractionGetter*(i: Interaction, api: RestApi): InteractionScanner =
    InteractionScanner(
        iact: i,
        api: api
    )

using scnr: InteractionScanner
##
## Getting data
##
proc getOption[T: string | int | bool](i: Interaction, key: string, kind: typedesc[T]): Option[T] =
    let opts = i.data.get().options
    if opts.hasKey(key):
        let option = opts[key]
        when T is string:
            result = option.str
        elif T is int:
            result = option.iVal
        elif T is bool:
            result = option.bval

    else:
        result = none T

# Basic types
proc get*(scnr; kind: typedesc[int], key: string):    Option[int]    = scnr.iact.getOption(key, int)
proc get*(scnr; kind: typedesc[bool], key: string):   Option[bool]   = scnr.iact.getOption(key, bool)
proc get*(scnr; kind: typedesc[string], key: string): Option[string] = scnr.iact.getOption(key, string)

proc get*[T: enum](scnr; kind: typedesc[T], key: string): Option[T] =
    let token = scnr.get(string, key)
    if token.isSome():
        for val in kind:
            if $val == token.get():
                return some val
    none kind

# Discord types
proc get*(scnr; kind: typedesc[User], key: string): Future[Option[User]] {.async.} =
    let userID = scnr.get(string, key)
    if userID.isSome():
        result = some await scnr.api.getUser(userID.get())
    else:
        result = none User

proc get*(scnr; kind: typedesc[Role], key: string): Future[Option[Role]] {.async.} =
    let roleID = scnr.get(string, key)
    if roleID.isSome():
        when libVer != "1.2.7":
            result = some await scnr.api.getGuildRole(scnr.iact.guildID, roleID.get())
        else:
            result = some await scnr.api.getGuildRole(scnr.iact.guildID.get(), roleID.get())

    else:
        result = none Role

proc get*(scnr; kind: typedesc[GuildChannel], key: string): Future[Option[GuildChannel]] {.async.} =
    let guildID = scnr.get(string, key)
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