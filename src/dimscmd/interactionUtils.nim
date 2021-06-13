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
    InteractionCommand = object
        name: string
        description: string

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
proc getString*(i: Interaction, key: string): Option[string] = i.getOption(key, string)
proc getInt*(i: Interaction, key: string):    Option[int] = i.getOption(key, int)
proc getBool*(i: Interaction, key: string):   Option[bool] = i.getOption(key, bool)

# Discord types
proc getUser*(i: Interaction, key: string, api: RestApi): Future[Option[User]] {.async.} =
    let userID = i.getString(key)
    if userID.isSome():
        result = some await api.getUser(userID.get())
    else:
        result = none User

proc getRole*(i: Interaction, key: string, api: RestApi): Future[Option[Role]] {.async.} =
    let roleID = i.getString(key)
    if roleID.isSome():
        when libVer != "1.2.7":
            result = some await api.getGuildRole(i.guildID, roleID.get())
        else:
            result = some await api.getGuildRole(i.guildID.get(), roleID.get())

    else:
        result = none Role

proc getGuildChannel*(i: Interaction, key: string, api: RestApi): Future[Option[GuildChannel]] {.async.} =
    let guildID = i.getString(key)
    if guildID.isSome():
        result = some (await api.getChannel(guildID.get()))[0].get()
    else:
        result = none GuildChannel

##
## Adding data
##

macro newCmdBuilder(name: untyped, cmdType: ApplicationCommandOptionType): untyped =
    # Used for the basic slash types (basically everything but enums)
    # Generates a builder proc that is used to add another option to a command
    result = quote do:
        proc `name`(cmd: var ApplicationCommand, name, description: string, required = true) =
            cmd.options &= ApplicationCommandOption(
                kind: ApplicationCommandOptionType(`cmdType`),
                name: name,
                description: description,
                required: some required
            )

proc newApplicationCommand(name, description: string): ApplicationCommand =
  result = ApplicationCommand(
        name: name,
        description: description
  )


newCmdBuilder(addString, acotStr)
newCmdBuilder(addInt, acotInt)
newCmdBuilder(addBool, acotBool)
newCmdBuilder(addUser, acotUser)
newCmdBuilder(addRole, acotRole)
newCmdBuilder(addGuildChannel, acotChannel)