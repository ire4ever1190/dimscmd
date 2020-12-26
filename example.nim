import dimscord, asyncdispatch, strutils
import random
import src/dimscmd
import options

# Initialise everthing
const token = readFile("token").strip()
let discord = newDiscordClient(token)
randomize()

proc reply(m: Message, msg: string): Future[Message] {.async.} =
    result = await discord.api.sendMessage(m.channelId, msg)

# Define your commands
proc ping() {.command.} =
    ## I will pong your ping
    discard await msg.reply("pong") # The msg variable is the same has the one that you declare in the message_create event

proc dice() {.ncommand(name = "rollDice").} = # Command will be rollDice instead of dice
    discard await msg.reply($rand(1..6))

proc echo(word: string, times: int) {.command.} =
    ## I repeat the word back to you
    discard await msg.reply((word & " ").repeat(times))

var t = 0
discord.events.interaction_create = proc (s: Shard, i: Interaction) {.async.} =
    slashCommandHandler(i)
    
# Do discord events like normal
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Getting application"
    # let application = await discord.api.getCurrentApplication()
    # echo application
    await sleepAsync(4000)  
    let options = @[
        ApplicationCommandOption(
            kind: acotStr,
            name: "Word",
            required: some true,
            description: "The input you want to say"
        )
    ]
    discard await discord.api.registerApplicationCommand("742010764302221334", guildID = "479193574341214208", name = "echo", description = "Echos what you says", options = options)
    # discard await discord.api.registerApplicationCommand("742010764302221334", guildID = "479193574341214208", name = "kayne", description = "This is a test")
    echo "Ready as " & $r.user

discord.events.message_create = proc (s: Shard, msg: Message) {.async.} =
    if msg.author.bot: return
    commandHandler("$$", msg) # Let the magic happen

waitFor discord.startSession()
