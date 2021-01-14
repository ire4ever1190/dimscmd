import unittest
include dimscordMock
import dimscmd
import strutils
import sugar
#
# Test commands
#
const token = readFile("token").strip()
let discord = newDiscordClient(token) # Maybe work on something that allows better testing?
var cmd = discord.newHandler()

cmd.addChat("ping") do ():
    discard await discord.api.sendMessage("pong")

#
# Tests
#

test "Basic command":
    var message = Message(content: "!!ping")
    check waitFor cmd.handleMessage("!!", Message)
    var message = waitFor discord.api.recvMessage()
