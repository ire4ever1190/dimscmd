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

proc dice() {.command.} = # Command will be rollDice instead of dice
    ## $name: rollDice
    discard await msg.reply($rand(1..6))

proc echo(word: string, times: int) {.command.} =
    ## I repeat the word back to you
    discard await msg.reply((word & " ").repeat(times))

proc ping() {.slashCommand.} =
    ## $name: wiisports
    ## $guildID: 479193574341214208 
    ## I can get to 100 in wii sports ping pong
    echo "hello"

proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
    slashCommandHandler(i)
    
# Do discord events like normal
proc onReady (s: Shard, r: Ready) {.event(discord).} =
    await discord.api.registerCommands("742010764302221334")
    echo "Ready as " & $r.user

proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    if msg.author.bot: return
    commandHandler("$$", msg) # Let the magic happen

waitFor discord.startSession()
