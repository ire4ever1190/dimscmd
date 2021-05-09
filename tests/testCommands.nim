import unittest
import asyncdispatch
import dimscmd
import strutils
import dimscord
#
# Test commands
#
let discord = newDiscordClient("token")
var cmd = discord.newHandler()

var latestMessage = ""

cmd.addChat("ping") do ():
    latestMessage = "pong"

cmd.addChat("var") do (c: Message):
    latestMessage = c.content

#
# Tests
#

test "Basic command":
    var message = Message(content: "!!ping")
    check waitFor cmd.handleMessage("!!", message)
    check latestMessage == "pong"
    
test "Different command variable":
    var message = Message(content: "!!var")
    check waitFor cmd.handleMessage("!!", message)
    check latestMessage == "!!var"
