import dimscord
import dimscmd
import dimscmd/interactionUtils
include token
import std/unittest
import std/asyncdispatch
import std/strutils
import std/os
import std/options
import std/exitprocs
import std/json
import std/tables

#
# Test commands
#

let discord = newDiscordClient(token)


var cmd = discord.newHandler()

proc onReady (s: Shard, r: Ready) {.event(discord).} =
    await cmd.registerCommands()

var latestMessage = ""



template sendInteraction(cmdName: string, cmdOptions: JsonNode, expected = true) =
    var interaction = Interaction()
    var command = ApplicationCommandInteractionData(
        interactionType: idtApplicationCommand,
        name: cmdName,
        kind: atSlash)
    for option in cmdOptions.items:
        var newOption = ApplicationCommandInteractionDataOption(
            kind: ApplicationCommandOptionType option["kind"].getInt()
        )
        let val = option["value"]
        # Q: Is this basically rewriting the code in dimscord?
        # A: perhaps
        case newOption.kind:
            of acotInt:
                newOption.ival      = val.getInt()
            of acotStr:
                newOption.str       = val.getStr()
            of acotBool:
                newOption.bval      = val.getBool()
            of acotUser:
                newOption.userID    = val.getStr()
            of acotRole:
                newOption.roleID    = val.getStr()
            of acotChannel:
                newOption.channelID = val.getStr()
            else: discard
        command.options[option["name"].getStr()] = newOption
    interaction.data = some command
    when interaction.guildId is string:
        interaction.guildId = "479193574341214208"
    else:
        interaction.guildId = some "479193574341214208"
    check cmd.handleInteraction(nil, interaction).waitFor() == expected

cmd.addSlash("basic") do ():
    ## Does nothing
    latestMessage = "hello world"

cmd.addSlash("echo") do (word {.help: "test".}: string):
    ## Sends the word back
    latestMessage = word

cmd.addSlash("sum") do (a: int, b: int):
    ## Adds a and b together
    latestMessage = $(a + b)

cmd.addSlash("poem") do (x: bool):
    ## 2b or not 2b
    if x:
        latestMessage = "2b"
    else:
        latestMessage = "not 2b"

cmd.addSlash("musk") do (a: string, b: int, c: bool):
    ## Tests all three
    if c:
        latestMessage = a.repeat(b)
    else:
        latestMessage = a & " " & $b & " " & $c

cmd.addSlash("say") do (a: Option[string]):
    ## replies with what the user sends, else you can hear crickets
    if a.isSome():
        latestMessage = a.get()
    else:
        latestMessage = "*crickets*"

cmd.addSlash("user") do (user: User):
    ## Returns the users name
    latestMessage = user.username

cmd.addSlash("chan") do (channel: Channel):
    ## Returns the channel name
    latestMessage = channel.name

cmd.addSlash("role") do (role: Role):
    ## Returns the role name
    latestMessage = role.name

cmd.addSlash("userq") do (user: Option[User]):
    ## L
    if user.isSome():
        latestMessage = "The user is " & user.get().username
    else:
        latestMessage = "no user"

cmd.addSlash("calc add") do (a: int, b: int):
  ## Adds two values
  latestMessage = $(a + b)

cmd.addSlash("calc times") do (a: int, b: int):
  ## Multiples two values
  latestMessage = $(a * b)

cmd.addSlash("cases") do (camelCase: int, snakeCase: int, PascalCase: int):
  ## Check that other cases are supported during registration
  latestMessage = $(camelCase + snakeCase + PascalCase)

cmd.addSlashAlias("calc add", ["calc plus", "calc addition"])

# Stub so the `someSeq` test compiles
proc get(scanner: InteractionScanner, kind: typedesc[seq[int]], key: string): Option[seq[int]] =
  discard

cmd.addSlash("someSeq") do (test: seq[int]):
  ## Checks that `seq[T]` is correctly a `seq`.
  ## This check happens at compile time
  static:
    assert typeof(test) is seq[int], $typeof(test)

proc newParam[T](name: string, val: T, kind: ApplicationCommandOptionType): JsonNode =
  result = %* {"name": name, "value": %val, "kind": kind.ord}

proc newParam[T](name: string, val: T): JsonNode =
  let kind = (when T is string: acotStr
              elif T is int: acotInt
              elif T is bool: acotBool
              else: {.error: "Unsupported type " & $T.})
  newParam(name, val, kind)


proc onReady(s: Shard, r: Ready) {.event(discord).} =
    await cmd.registerCommands()
    test "Basic":
        sendInteraction("basic", %* [])
        check latestMessage == "hello world"

    suite "Primitives":
        test "String":
            sendInteraction("echo", %* [
              newParam("word", "johndoe")
            ])
            check latestMessage == "johndoe"

        test "Integer":
            sendInteraction("sum", %* [
              newParam("a", 5),
              newParam("b", 9)
            ])
            check latestMessage == "14"

        test "Boolean":
            sendInteraction("poem", %* [
              newParam("x", false)
            ])
            check latestMessage == "not 2b"
            sendInteraction("poem", %* [
              newParam("x", true)
            ])
            check latestMessage == "2b"

        test "All three":
            sendInteraction("musk", %* [
              newParam("a", "hello"),
              newParam("b", 2),
              newParam("c", true)
            ])
            check latestMessage == "hellohello"
            sendInteraction("musk", %* [
              newParam("a", "hello"),
              newParam("b", 2),
              newParam("c", false)
            ])
            check latestMessage == "hello 2 false"
        test "Optional types":
            sendInteraction("say", %* [])
            check latestMessage == "*crickets*"
            sendInteraction("say", %* [
              newParam("a", "cat")
            ])
            check latestMessage == "cat"

    suite "Discord types":
        test "User":
            sendInteraction("user", %* [
              newParam("user", "259999449995018240", acotUser)
            ])
            check latestMessage == "intellij_gamer"

        test "Channel":
            sendInteraction("chan", %* [
              newParam("channel", "479193574341214210", acotChannel)
            ])
            check latestMessage == "general"

        test "Role":
            sendInteraction("role", %* [
              newParam("role", "483606693180342272", acotRole)
            ])
            check latestMessage == "Supreme Ruler"

        test "Optional": # Just test optional user, but they all use the same system
            sendInteraction("userq", %* [])
            check latestMessage == "no user"
            sendInteraction("userq", %* [
              newParam("user", "259999449995018240", acotUser)
            ])
            check latestMessage == "The user is intellij_gamer"

    proc newAddCommand(a, b: int, child = "add"): Interaction =
      ## Creates a new `calc add` command
      let data = %* {
        "version": 1,
        "type": 2,
        "token": "asdfghjkjuyhtrdsxcvbnjhgf",
        "id": "3456789",
        "guild_id": "45678654567",
        "data": {
          "type": 1,
          "options": [
            {
              "type": 1,
              "options": [
                {
                  "value": a,
                  "type": 4,
                  "name": "a"
                },
                {
                  "value": b,
                  "type": 4,
                  "name": "b"
                }
              ],
              "name": child
            }
          ],
          "name": "calc",
          "id": "5686538443854843854"
        },
        "channel_id": "4657896957",
        "application_id": "465768758"
      }
      result = newInteraction data

    test "Sub commands":
      let interaction = newAddCommand(10, 12)
      check interaction.getWords() == @["calc", "add"]
      check waitFor cmd.handleInteraction(nil, interaction)
      check latestMessage == "22"

    test "Doesn't error when command doesn't exist":
      sendInteraction("noexist", %* [], false)

    test "Can alias slash commands":
      block:
        let interaction = newAddCommand(56, 10, "plus")
        check waitFor cmd.handleInteraction(nil, interaction)
        check latestMessage == "66"
      block:
        let interaction = newAddCommand(1, 2, "addition")
        check waitFor cmd.handleInteraction(nil, interaction)
        check latestMessage == "3"

    test "Different cases are supported":
      sendInteraction("cases", %* [
        newParam("camelcase", 1),
        newParam("snakecase", 1),
        newParam("_pascalcase", 1)
      ])
      check latestMessage == "3"

    quit getProgramResult()

waitFor discord.startSession()
