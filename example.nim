import dimscord, asyncdispatch, strutils
import random
import src/dimscordCommandHandler

# Initialise everthing
const token = readFile("token").strip()
let discord = newDiscordClient(token)
randomize()

# Define your commands
proc ping() {.command.} =
    ## I will pong your ping
    discard await discord.api.sendMessage(msg.channelId, "pong") # The msg variable is the same has the one that you declare in the handler

proc dice() {.command.} =
    discard await discord.api.sendMessage(msg.channelId, $rand(1..6))

# Do discord events like normal
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user

discord.events.message_create = proc (s: Shard, msg: Message) {.async.} =
    if msg.author.bot: return
    commandHandler("$$", msg) # Let the magic happen

waitFor discord.startSession()
