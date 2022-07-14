import dimscord, asyncdispatch, strutils
import random
import strformat
import src/dimscmd
import json
import options

# Initialise everthing
const token = readFile("token").strip()
let discord = newDiscordClient(token)
var cmd = discord.newHandler() # Must be var
randomize()

# This variable defines the default guild to register slash commands in
# Can be put in a when statement to change between debug/prod builds
const dimscordDefaultGuildID = "479193574341214208"


proc reply(m: Message, msg: string): Future[Message] {.async.} =
    result = await discord.api.sendMessage(m.channelId, msg)

proc reply(i: Interaction, msg: string) {.async.} =
    echo i
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
            content: msg
        )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)

type Colour = enum
    Red
    Green
    Blue = "bloo" # passport

cmd.addChat("hi") do ():
    ## I say hello back
    discard await msg.reply("Hello")

cmd.addChat("cat") do (colour: Colour): # Enums are supported for chat commands
    discard msg.reply("The big " & $colour & " cat")

cmd.addChat("kill") do (user: Option[User]):
        if user.isSome():
            discard await discord.api.sendMessage(msg.channelID, "Killing them...")
            # TODO, see if this is legal before implementing
        else:
            discard await discord.api.sendMessage(msg.channelID, "I can't kill nobody")

cmd.addChat("echo") do (toEcho {.help: "The word that you want me to echo"}: string, times: int):
    ## I will repeat what you say
    # echo toEcho
    discard await msg.reply(repeat(toEcho & " ", times))

cmd.addChat("echoAll") do (toEcho: seq[string]):
    ## I will say a list of words
    for word in toEcho:
        discard await msg.reply(word)

cmd.addChat("channelInfo") do (chan: Channel):
    # let chan = await channelFuture # This is needed for now
    echo chan.name
    discard await msg.reply("Channel: " & chan.name & "\n" & "ID: " & chan.id)

cmd.addChat("channels") do (channels: seq[Channel]):
    var response = ""
    for channel in channels:
        response &= channel.name & "\n"
    discard await msg.reply(response)

cmd.addChat("sum") do (nums: seq[int]):
    ## Sums up all your numbers
    var sum = 0
    for num in nums: sum.inc num
    discard msg.reply($sum)

cmd.addChat("username") do (user: User):
    ## Echos the persons username
    discard msg.reply(user.username)

cmd.addChat("role") do (role: Role):
    discard msg.reply(role.name)

cmd.addChat("calc sum") do (a: int, b: int):
    discard msg.reply($(a + b))

cmd.addChat("calc times") do (a: int, b: int):
    discard msg.reply($(a * b))



cmd.addSlash("somecmd") do (name: Option[string]):
    ## Does something
    let nameVal = name.get("some default value")
    await i.reply(nameVal)

cmd.addChat("isPog") do (pog: bool): # I hate myself
    ## Pogging
    if pog:
        discard msg.reply("poggers")
    else:
        discard msg.reply("pogn't")

cmd.addSlash("user", guildID = dimscordDefaultGuildID) do (user: User):
    ## Pog?
    echo "id: ", i.id
    echo "token: ", i.token
    await i.reply(user.username)

cmd.add_slash("add") do (a: int, b: int):
    ## Adds two numbers
    await i.reply(fmt"{a} + {b} = {a + b}")

cmd.addSlash("rgb", guildID = "479193574341214208") do (colour: Colour):
    ## Adds two numbers
    await i.reply(fmt"You have selected {colour}")

cmd.addSlash("only", guildID = "479193574341214208") do (num: int, test: Option[string]):
    ## runs only in the guild with id 479193574341214208
    echo "secret"

cmd.addSlash("calc add", guildID = dimscordDefaultGuildID) do (
        a {.help: "First number you want to add"}: int,
        b {.help: "Second number you want to add"}: int):
    ## Adds two numbers together
    await i.reply(fmt"{a} + {b} = {a + b}")

cmd.addSlash("calc check") do (a, b: int):
    ## Checks if two numbers are equal
    await i.reply($(a == b))

cmd.addSlash("calc times", guildID = dimscordDefaultGuildID) do (a: int, b: int):
    ## multiplies two numbers together
    await i.reply(fmt"{a} * {b} = {a * b}")



proc onDispatch(s: Shard, evt: string, data: JsonNode) {.event(discord).} =
    echo data.pretty()

# Do discord events like normal
proc onReady (s: Shard, r: Ready) {.event(discord).} =
    await cmd.registerCommands()
    echo "Ready as " & $r.user

proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
    discard await cmd.handleInteraction(s, i)

proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    if msg.author.bot: return
    # Let the magic happen
    discard await cmd.handleMessage("$$", s, msg) # Returns true if a command was handled
    # Or you can pass a list of prefixes
    # discard await cmd.handleMessage(["$$", "@"], s, msg)
waitFor discord.startSession()
