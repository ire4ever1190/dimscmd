import unittest
import asyncdispatch
import dimscmd
import strutils
import dimscord
import os
import options
#
# Test commands
#
# abortOnError = true
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

cmd.addChat("chan") do (channel: Channel):
    latestMessage = channel.name

# cmd.addChat("chans") do (channels: seq[Channel]):
#     latestMessage = ""
#     for channel in channels:
#         latestMessage &= channel.name

cmd.addChat("username") do (user: User):
    latestMessage = user.username

# cmd.addChat("usernames") do (users: seq[User]):
#     latestMessage = ""
#     for user in users:
#         latestMessage &= user.username & " "

cmd.addChat("role") do (role: Role):
    latestMessage = role.name


template sendMsg(msg: string, prefix: untyped = "!!") =
    var message = Message(content: prefix & msg, guildID: some "479193574341214208")
    check waitFor cmd.handleMessage(prefix, message)

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Running tests"
    test "Basic command":
        sendMsg("ping")
        check latestMessage == "pong"

    test "Different command variable":
        sendMsg("var")
        check latestMessage == "!!var"

    test "Multiple prefixes":
        var message = Message(content: "!!ping")
        check waitFor cmd.handleMessage(@["!!", "$"], message)
        check latestMessage == "pong"

        message = Message(content: "$ping")
        check waitFor cmd.handleMessage(@["!!", "$"], message)
        check latestMessage == "pong"

    suite "Parsing parameters":
        test "Simple parameters":
            sendMsg("repeat hello 4")
            check latestMessage == "hellohellohellohello"

        test "Channel mention":
            sendMsg("chan <#479193574341214210>")
            check latestMessage == "general"

        test "Channel mentions":
            sendMsg("chan <#479193574341214210> <#479193924813062152>")
            check latestMessage == "general bots-playground "

        test "User mention":
          sendMsg("username <@!742010764302221334>")
          check latestMessage == "Kayne"

        test "User Mentions":
          sendMsg("usernames <@!742010764302221334> <@!259999449995018240>")
          check latestMessage == "Kayne amadan "

        test "Role mention":
            sendMsg("role <@&483606693180342272>")
            check latestMessage == "Supreme Ruler"

        test "Role mention":
            sendMsg("roles <@&483606693180342272> <@&483606693180342272>")
            check latestMessage == "Supreme Ruler Supreme Ruler "

        test "Sequence of one type":
            sendMsg("sum 1 2 3")
            check latestMessage == "6"

        test "Sequence followed by another type":
            sendMsg("sumrepeat 1 2 3 hello")
            check latestMessage == "hellohellohellohellohellohello"

        test "Sequence of two types":
            # var message = Message(content: "!!twotypes 2 3 hello world")
            # check waitFor cmd.handleMessage("!!", message)
            sendMsg("twotypes 2 3 hello world")
            check latestMessage == "hellohello worldworldworld "

    quit 0

waitFor discord.startSession()