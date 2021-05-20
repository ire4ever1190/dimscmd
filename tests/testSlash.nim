import unittest
import asyncdispatch
import dimscmd
import strutils
import dimscord
import os
import options
import std/exitprocs
import std/json
import std/tables
#
# Test commands
#

const token = readFile("token").strip()
let discord = newDiscordClient(token)
var cmd = discord.newHandler()

var latestMessage = ""



template sendInteraction(cmdName: string, cmdOptions: JsonNode) =
    var interaction = Interaction()
    var command = ApplicationCommandInteractionData(name: cmdName)
    for k, v in cmdOptions.pairs:
        var option = ApplicationCommandInteractionDataOption()
        case v.kind:
            of JString:
                option.str = some v.getStr()
            of JInt:
                option.ival = some v.getInt()
            of JBool:
                option.bval = some v.getBool()
            else: discard
        command.options[k] = option
    interaction.data = some command
    check waitFor cmd.handleInteraction(nil, interaction)

cmd.addSlash("basic") do ():
    ## Does nothing
    latestMessage = "hello world"

cmd.addSlash("echo") do (word: string):
    ## Sends the word back
    latestMessage = word

cmd.addSlash("sum") do (a: int, b: int):
    ## Adds a and b together
    latestMessage = $(a + b)

cmd.addSlash("poem") do (x: bool):
    ## 2b or not 2b
    if x:
        latestMessage = "2b"
    else:
        latestMessage = "not 2b"

cmd.addSlash("musk") do (a: string, b: int, c: bool):
    ## Tests all three
    if c:
        latestMessage = a.repeat(b)
    else:
        latestMessage = a & " " & $b & " " & $c

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    test "Basic":
        sendInteraction("basic", newJObject())
        check latestMessage == "hello world"

    suite "Primitives":
        test "String":
            sendInteraction("echo", %* {"word": "johndoe"})
            check latestMessage == "johndoe"

        test "Integer":
            sendInteraction("sum", %* {"a": 5, "b": 9})
            check latestMessage == "14"

        test "Boolean":
            sendInteraction("poem", %* {"x": false})
            check latestMessage == "not 2b"
            sendInteraction("poem", %* {"x": true})
            check latestMessage == "2b"

        test "All three":
            sendInteraction("musk", %* {"a": "hello", "b": 2, "c": true})
            check latestMessage == "hellohello"
            sendInteraction("musk", %* {"a": "hello", "b": 2, "c": false})
            check latestMessage == "hello 2 false"
    quit getProgramResult()

waitFor discord.startSession()
