import dimscord, asyncdispatch, strutils
import random
import strformat
import src/dimscmd
import options

# Initialise everthing
const token = readFile("token").strip()
let discord = newDiscordClient(token)
var cmd = discord.newHandler() # Must be var
randomize()

# This variable defines the default guild to register slash commands in
# Can be put in a when statement to change between debug/prod builds
#dimscordDefaultGuildID = "479193574341214208"


proc reply(m: Message, msg: string): Future[Message] {.async.} =
    result = await discord.api.sendMessage(m.channelId, msg)



cmd.addChat("hi") do ():
    ## I say hello back
    discard await msg.reply("Hello")

cmd.addChat("button") do ():
    let components = @[MessageComponent(
        `type`: ActionRow,
        components: @[MessageComponent(
            `type`: Button,
            label: some "hello",
            style: some 1,
            customID: some "hello"
        )]
    )]
    discard await discord.api.sendMessage(msg.channelID, "hello", components = some components)

cmd.addChat("echo") do (toEcho {.help: "The word that you want me to echo"}: string, times: int):
    ## I will repeat what you say
    echo toEcho
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

cmd.addChat("isPog") do (pog: bool): # I hate myself
    ## Pogging
    if pog:
        discard msg.reply("poggers")
    else:
        discard msg.reply("pogn't")

cmd.addSlash("pog") do (pog: bool):
    ## Pog?
    if pog:
        echo "poggers"
    else:
        echo "pogn't"

cmd.addSlash("add") do (a: int, b: int):
    ## Adds two numbers
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
            content: fmt"{a} + {b} = {a + b}"
        )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("user") do (user: User):
    ## Returns user info
    echo i.data.get().options
    echo user

cmd.addSlash("only-guild", guildID = "699792432925245472") do (test: string):
    ## runs only in the guild with id 699792432925245472
    echo "secret"

# Do discord events like normal
proc onReady (s: Shard, r: Ready) {.event(discord).} =
    await cmd.registerCommands()
    echo "Ready as " & $r.user

proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
    echo i.data.get().id
    echo i.data.get().name
    discard await cmd.handleInteraction(s, i)

proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    echo msg.content
    if msg.author.bot: return
    # Let the magic happen
    discard await cmd.handleMessage("$$", msg) # Returns true if a command was handled
    # Or you can pass a list of prefixes
    # discard await cmd.handleMessage(["$$", "@"], msg)
waitFor discord.startSession()
