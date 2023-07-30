import dimscord
import std/[
    tables,
    macros,
    options,
    asyncdispatch,
    sequtils,
    strutils
]
import discordUtils

type
    InteractionCommandData = Table[string, ApplicationCommandInteractionDataOption]
    InteractionScanner* = object
        iact: Interaction
        data: InteractionCommandData
        api: RestApi

proc normaliseParameterName*(name: string): string =
  ## Mangles a parameter name so that discord will accept it.
  ## This allows camelCase and friends to be used.
  runnableExamples:
    doAssert normaliseParameterName("camelCase") == "camelcase"
    doAssert normaliseParameterName("snake_case") == "snakecase"
    # Start with _ since Nim normally is sensitive on the first capital but
    # we can't send the uppercase letter
    doAssert normaliseParameterName("PascalCase") == "_pascalcase"
  #==#
  if name.len == 0: return # Should really be invalid
  # To know if name is PascalCase, we append a _ to the beginning
  if name[0].isUpperAscii(): result = "_"
  result &= name.normalize()


template traverse(initData: Table[string, ApplicationCommandInteractionDataOption], body: untyped): untyped {.dirty.} =
    ## Used to run code to traverse down into the interaction tree.
    ## Does not run for root node so make sure to define your inital return value before this template
    var curr = initData
    while true:
        let children = toSeq(curr.values)
        # If it has a child and that child is either a sub command or sub group
        # then increase the search to the next node.
        # Else break the loop since `result` contains the parameters for the command
        if children.len == 1 and children[0].kind in {acotSubCommandGroup, acotSubCommand}:
            body
            curr = children[0].options
        else:
            break

proc getWords*(i: Interaction): seq[string] =
    ## Returns a list of sub command group names and a final sub command name
    ## in an interaction
    let data = i.data.get()
    result &= data.name
    data.options.traverse:
        result &= children[0].name

proc getTail*(data: ApplicationCommandInteractionData): InteractionCommandData =
    ## Returns the tail end of the application data which contains all the
    ## parameters past to the command.
    result = data.options
    data.options.traverse:
        result = children[0].options

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
        prop: untyped): Option[kind] {.dirty.} =
    bind hasKey
    bind `[]`
    block:
      let mangledKey = normaliseParameterName(key)
      if opts.hasKey(mangledKey):
        some kind(opts[mangledKey].prop)
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
        when compiles(scnr.api.getGuildRole(scnr.iact.guildID, roleID.get())):
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

export tables
