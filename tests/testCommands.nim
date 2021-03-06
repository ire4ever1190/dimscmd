import unittest
import asyncdispatch
import dimscmd
import strutils
import dimscord
import dimscmd/[
    scanner,
    common
]
import os
include token
import options
import std/exitprocs
import std/tables
#
# Test commands
#

let discord = newDiscordClient(token)
var cmd = discord.newHandler()

var latestMessage = ""

type Colour = enum
    Red
    Green
    Blue = "bloo"

cmd.addChat("ping") do ():
    ## Returns pong
    latestMessage = "pong"

cmd.addChat("var") do (c: Message):
    latestMessage = c.content

cmd.addChat("repeat") do (word: string, count: int):
    latestMessage = word.repeat(count)

cmd.addChat("sum") do (nums: seq[int]):
    var total = 0
    for num in nums: total += num
    latestMessage = $total

cmd.addChat("isPog") do (pog: bool): # I hate myself
    if pog:
        latestMessage = "poggers"
    else:
        latestMessage = "pogn't"

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

cmd.addChat("colour") do (colour: Colour):
    case colour:
        of Red, Green:
            latestMessage = $colour
        of Blue:
            latestMessage = $colour & " passport"

type Email = object
  user, domain: string

proc next(scanner: CommandScanner, kind: typedesc[Email]): Email =
    ## This implements the `next` proc for Email which allows using it as a type for a command
    scanner.skipWhitespace()
    result.user = scanner.parseUntil('@')
    if result.user == "": raiseScannerError("Invalid email, must be in format user@domain")
    scanner.skipPast("@")
    result.domain = scanner.parseUntil(' ')

cmd.addChat("email") do (email: Email): # Email =
    latestMessage = "Ok, I'll send an email to " & email.user & " at " & email.domain

cmd.addChat("chans") do (channels: seq[Channel]):
    latestMessage = ""
    for channel in channels:
        latestMessage &= channel.name & " "

cmd.addChat("username") do (user: User):
    latestMessage = user.username

cmd.addChat("usernames") do (users: seq[User]):
    latestMessage = ""
    for user in users:
        latestMessage &= user.username & " "

cmd.addChat("role") do (role: Role):
    latestMessage = role.name

cmd.addChat("dosay") do (word: Option[string]):
    if word.isSome():
        latestMessage = word.get()
    else:
        latestMessage = "*crickets*"

cmd.addChat("roles") do (roles: seq[Role]):
    latestMessage = ""
    for role in roles:
        latestMessage &= role.name & " "

cmd.addChat("calc sum") do (a: int, b: int):
    latestMessage = $(a + b)

cmd.addChat("calc times") do (a: int, b: int):
    latestMessage = $(a * b)


template sendMsg(msg: string, prefix: untyped = "!!") =
    var message = Message(content: prefix & msg, guildID: some "479193574341214208")
    check waitFor cmd.handleMessage(prefix, message)

test "Documentation on command":
    check cmd.chatCommands.get(["ping"]).description == "Returns pong"

proc onReady(s: Shard, r: Ready) {.event(discord).} =
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

        test "Boolean value":
            sendMsg("isPog yes")
            check latestMessage == "poggers"

        test "Channel mention":
            sendMsg("chan <#479193574341214210>")
            check latestMessage == "general"

        test "Channel mentions":
            sendMsg("chans <#479193574341214210> <#479193924813062152>")
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
            sendMsg("twotypes 2 3 hello world")
            check latestMessage == "hellohello worldworldworld "

    suite "Optional types":
        test "Passing nothing":
            sendMsg("dosay")
            check latestMessage == "*crickets*"
        test "Passing something":
            sendMsg("dosay hello")
            check latestMessage == "hello"

    test "ISSUE: Invalid channel response msg is greater than 2000 characters":
        # Somehow the error message for this is 2257 characters long
        # I shouldn't be anywhere near that
        # Resolved, turns out async adds the stacktrace to the msg
        expect RestError: # Don't expect an Assert error
            sendMsg("chan <#1234>")

    test "Custom type parsing":
        sendMsg("email test@example.com")
        check latestMessage == "Ok, I'll send an email to test at example.com"

    test "Text sub commands":
        sendMsg("   calc sum   6 4")
        check latestMessage == "10"
        sendMsg("calc     times 9 8")
        check latestMessage == "72"

    test "Enums":
        sendMsg("colour red")
        check latestMessage == "Red"
        sendMsg("colour bloo")
        check latestMessage == "bloo passport"

    quit getProgramResult()

waitFor discord.startSession()
