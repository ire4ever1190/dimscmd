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

cmd.addChatAlias("ping", ["p", "pi"])

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

# cmd.addChat("dice") do (sides: range[2..high(int)]): # Two sided minimum
    # latestMessage = $sides # sorta random

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

cmd.addChat("roles") do (roles {.help: "test".}: seq[Role]):
    latestMessage = ""
    for role in roles:
        latestMessage &= role.name & " "

cmd.addChat("calc sum") do (a: int, b: int):
    ## Adds two numbers together
    latestMessage = $(a + b)

cmd.addChatAlias("calc sum", ["ca add"])

cmd.addChat("calc times") do (a: int, b: int):
    latestMessage = $(a * b)

cmd.addChat("say english greeting") do ():
    latestMessage = "Hello world"

cmd.addChat("say english goodbye") do ():
    latestMessage = "Goodbye friends"

cmd.addChat("say irish goodbye") do ():
    latestMessage = "slan"

cmd.addChat("string") do (strings: seq[string]):
    check strings.len == 4
    latestMessage = strings.join(" ")
    discard

using xUsing: string
import macros
macro t(x: typed) =
  echo x.treeRepr
t(proc(xUsing) = discard)

cmd.addChat("using") do (xUsing):
  latestMessage = xUsing

# cmd.addChat("variablearray") do (nums: array[1..4, int]):
#     # latestMessage = sum(nums)
#     discard

cmd.addChat("nimsyntax") do (a, b, c: int, s: string):
    latestMessage = s & " " & $(a + b + c)


template sendMsg(msg: string, prefix: untyped = "!!") =
    var message = Message(content: prefix & msg, guildID: some "479193574341214208")
    check waitFor cmd.handleMessage(prefix, message)

template checkLatest(msg: string) =
    ## Checks if the latest message against `msg` and then clears it
    check latestMessage == msg
    latestMessage = ""

test "Documentation on command":
    check cmd.chatCommands.get(["ping"]).description == "Returns pong"

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    test "Basic command":
        sendMsg("ping")
        checkLatest "pong"

    test "Different command variable":
        sendMsg("var")
        checkLatest "!!var"

    test "Space before command":
        sendMsg("   ping")
        check latestMessage == "pong"

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

    suite "Command Groups":
        test "Text sub commands":
            sendMsg "calc sum 6 25"
            checkLatest "31"

        test "Space before command group":
            sendMsg("   calc sum   6 4")
            checkLatest "10"

        test "Space between commands":
            sendMsg("calc     times 9 8")
            checkLatest "72"

        test "Calling command that doesn't exist":
            var message = Message(content: "!!calc divide 12 4", guildID: some "479193574341214208")
            check not waitFor cmd.handleMessage("!!", message)

        test "Higher depth than 1":
            sendMsg("say english greeting")
            check latestMessage == "Hello world"
            sendMsg("say irish goodbye")
            check latestMessage == "slan"

    test "Enums":
        sendMsg("colour red")
        check latestMessage == "Red"
        sendMsg("colour bloo")
        check latestMessage == "bloo passport"

    # test "Ranges":
        # sendMsg("dice 6")
        # check latestMessage == "6"

    test "Simple nim syntax parameters":
        sendMsg("nimsyntax 1 2 3 hello")
        check latestMessage == "hello 6"

    suite "Alias":
        test "Single word command alias":
            sendMsg "p"
            checkLatest "pong"
            sendMsg "pi"
            checkLatest "pong"

        test "Sub command aliasing":
            sendMsg "calc sum 5 6"
            check latestMessage == "11"
            latestMessage = ""
            sendMsg "ca add 5 6"
            check latestMessage == "11"

    test "Using":
      sendMsg("using stuff")
      check latestMessage == "stuff"
    # suite "Arrays":
        # test "Basic array":
            # sendMsg("array i am bob hello world")
            # check latestMessage == "i am boob hello"
# 
        # test "Variable array":
            # sendMsg("variablearray 1 2")
            # check latestMessage == "3"
            # sendMsg("variablearray 1 2 3")
            # check latestMessage == "6"

    quit getProgramResult()

waitFor discord.startSession()
