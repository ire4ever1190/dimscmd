import dimscord
import dimscmd
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

const token = readFile("token").strip()
let discord = newDiscordClient(token)
var cmd = discord.newHandler()

var latestMessage = ""



template sendInteraction(cmdName: string, cmdOptions: JsonNode) =
    var interaction = Interaction()
    var command = ApplicationCommandInteractionData(name: cmdName)
    for k, v in cmdOptions.pairs:
        var option = ApplicationCommandInteractionDataOption()
        case v.kind:
            of JString:
                option.str = some v.getStr()
            of JInt:
                option.ival = some v.getInt()
            of JBool:
                option.bval = some v.getBool()
            else: discard
        command.options[k] = option
    interaction.data = some command
    interaction.guildId = some "479193574341214208"
    check waitFor cmd.handleInteraction(nil, interaction)

cmd.addSlash("basic") do ():
    ## Does nothing
    latestMessage = "hello world"

cmd.addSlash("echo") do (word: string):
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

cmd.addSlash("user?") do (user: Option[User]):
    ## L
    if user.isSome():
        latestMessage = user.get().username
    else:
        latestMessage = "no user"

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    test "Basic":
        sendInteraction("basic", newJObject())
        check latestMessage == "hello world"

    suite "Primitives":
        test "String":
            sendInteraction("echo", %* {"word": "johndoe"})
            check latestMessage == "johndoe"

        test "Integer":
            sendInteraction("sum", %* {"a": 5, "b": 9})
            check latestMessage == "14"

        test "Boolean":
            sendInteraction("poem", %* {"x": false})
            check latestMessage == "not 2b"
            sendInteraction("poem", %* {"x": true})
            check latestMessage == "2b"

        test "All three":
            sendInteraction("musk", %* {"a": "hello", "b": 2, "c": true})
            check latestMessage == "hellohello"
            sendInteraction("musk", %* {"a": "hello", "b": 2, "c": false})
            check latestMessage == "hello 2 false"
        test "Optional types":
            sendInteraction("say", %* {"a": nil})
            check latestMessage == "*crickets*"
            sendInteraction("say", %* {"a": "cat"})
            check latestMessage == "cat"

    suite "Discord types":
        test "User":
            sendInteraction("user", %* {"user": "259999449995018240"})
            check latestMessage == "amadan"

        test "Channel":
            sendInteraction("chan", %* {"channel": "479193574341214210"})
            check latestMessage == "general"

        test "Role":
            sendInteraction("role", %* {"role": "483606693180342272"})
            check latestMessage == "Supreme Ruler"

        test "Optional": # Just test optional user, but they all use the same system
            sendInteraction("user?", %* {"user": nil})
            check latestMessage == "no user"
            sendInteraction("user", %* {"user": "259999449995018240"})
            check latestMessage == "amadan"


    quit getProgramResult()

waitFor discord.startSession()
