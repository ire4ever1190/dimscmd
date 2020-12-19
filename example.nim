import dimscord, asyncdispatch, strutils
import random
import src/dimscmd

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

proc dice() {.command(name = "rollDice").} = # Command will be rollDice instead of dice
    discard await msg.reply($rand(1..6))

proc echo(word: string, times: int) {.command.} =
    ## I repeat the word back to you
    discard await msg.reply("word".repeat(6))

# Do discord events like normal
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user

discord.events.message_create = proc (s: Shard, msg: Message) {.async.} =
    if msg.author.bot: return
    commandHandler("$$", msg) # Let the magic happen

waitFor discord.startSession()
