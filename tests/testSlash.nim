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
    when libVer != "1.2.7" and libVer != "1.3.0":
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

cmd.addSlashAlias("calc add", ["calc plus", "calc addition"])

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    await cmd.registerCommands()
    test "Basic":
        sendInteraction("basic", %* [])
        check latestMessage == "hello world"

    suite "Primitives":
        test "String":
            sendInteraction("echo", %* [
                {"name": "word", "value": "johndoe", "kind": acotStr.ord}
            ])
            check latestMessage == "johndoe"

        test "Integer":
            sendInteraction("sum", %* [
                {"name": "a", "value": 5, "kind": acotInt.ord},
                {"name": "b", "value": 9, "kind": acotInt.ord}
            ])
            check latestMessage == "14"

        test "Boolean":
            sendInteraction("poem", %* [
                {"name": "x", "value": false, "kind": acotBool.ord}
            ])
            check latestMessage == "not 2b"
            sendInteraction("poem", %* [
                {"name": "x", "value": true, "kind": acotBool.ord}
            ])
            check latestMessage == "2b"

        test "All three":
            sendInteraction("musk", %* [
                {"name": "a", "value": "hello", "kind": acotStr.ord},
                {"name": "b", "value": 2, "kind": acotInt.ord},
                {"name": "c", "value": true, "kind": acotBool.ord}
            ])
            check latestMessage == "hellohello"
            sendInteraction("musk", %* [
                {"name": "a", "value": "hello", "kind": acotStr.ord},
                {"name": "b", "value": 2, "kind": acotInt.ord},
                {"name": "c", "value": false, "kind": acotBool.ord}
            ])
            check latestMessage == "hello 2 false"
        test "Optional types":
            sendInteraction("say", %* [])
            check latestMessage == "*crickets*"
            sendInteraction("say", %* [
                {"name": "a", "value": "cat", "kind": acotStr.ord}
            ])
            check latestMessage == "cat"

    suite "Discord types":
        test "User":
            sendInteraction("user", %* [
                {"name": "user", "value": "259999449995018240", "kind": acotUser.ord}
            ])
            check latestMessage == "amadan"

        test "Channel":
            sendInteraction("chan", %* [
                {"name": "channel", "value": "479193574341214210", "kind": acotChannel.ord}
            ])
            check latestMessage == "general"

        test "Role":
            sendInteraction("role", %* [
                {"name": "role", "value": "483606693180342272", "kind": acotRole.ord}
            ])
            check latestMessage == "Supreme Ruler"

        test "Optional": # Just test optional user, but they all use the same system
            sendInteraction("userq", %* [])
            check latestMessage == "no user"
            sendInteraction("userq", %* [
                {"name": "user", "value": "259999449995018240", "kind": acotUser.ord}
            ])
            check latestMessage == "The user is amadan"

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
        
    quit getProgramResult()

waitFor discord.startSession()
