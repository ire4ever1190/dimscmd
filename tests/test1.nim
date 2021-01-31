import unittest
import dimscord
import dimscmd
import strutils
import sugar
#
# Test commands
#
let discord = newDiscordClient("token")
var cmd = discord.newHandler()

var latestMessage = ""

cmd.addChat("ping") do ():
    latestMessage = "pong"

#
# Tests
#

test "Basic command":
    var message = Message(content: "!!ping")
    check waitFor cmd.handleMessage("!!", Message)
    check latestMessage == "pong"