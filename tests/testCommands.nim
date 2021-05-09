import unittest
import asyncdispatch
import dimscmd
import strutils
import dimscord
import os
#
# Test commands
#
const token = readFile("token").strip()
let discord = newDiscordClient(token)
var cmd = discord.newHandler()

var latestMessage = ""

cmd.addChat("ping") do ():
    latestMessage = "pong"

cmd.addChat("var") do (c: Message):
    latestMessage = c.content

cmd.addChat("repeat") do (word: string, count: int):
    latestMessage = word.repeat(count)

cmd.addChat("chan") do (channel: Channel):
    latestMessage = channel.name

cmd.addChat("sum") do (nums: seq[int]):
    var total = 0
    for num in nums: total += num
    latestMessage = $total

cmd.addChat("sumrepeat") do (nums: seq[int], word: string):
    var total = 0
    for num in nums: total += num
    latestMessage = word.repeat(total)

cmd.addChat("twotypes") do (nums: seq[int], words: seq[string]):
    latestMessage = ""
    for i in 0..<len(nums):
        latestMessage &= words[i].repeat(nums[i]) & " "

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Running tests"
    test "Basic command":
        var message = Message(content: "!!ping")
        check waitFor cmd.handleMessage("!!", message)
        check latestMessage == "pong"

    test "Different command variable":
        var message = Message(content: "!!var")
        check waitFor cmd.handleMessage("!!", message)
        check latestMessage == "!!var"

    suite "Parsing parameters":
        test "Simple parameters":
            var message = Message(content: "!!repeat hello 4")
            check waitFor cmd.handleMessage("!!", message)
            check latestMessage == "hellohellohellohello"

        test "Channel parameter":
            var message = Message(content: "!!chan <#479193574341214210>")
            check waitFor cmd.handleMessage("!!", message)
            check latestMessage == "general"

        test "Sequence of one type":
            var message = Message(content: "!!sum 1 2 3")
            check waitFor cmd.handleMessage("!!", message)
            check latestMessage == "6"

        test "Sequence followed by another type":
            var message = Message(content: "!!sumrepeat 1 2 3 hello")
            check waitFor cmd.handleMessage("!!", message)
            check latestMessage == "hellohellohellohellohellohello"

        test "Sequence of two types":
            var message = Message(content: "!!twotypes 2 3 hello world")
            check waitFor cmd.handleMessage("!!", message)
            check latestMessage == "hellohello worldworldworld "

    quit 0

waitFor discord.startSession()