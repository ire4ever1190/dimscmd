import unittest
include dimscmd
import strutils
import sugar
from dimscord import Channel
#
# Test commands
#

proc test(): int {.command.} =
    ## I return 50
    return 50

proc hello() {.command.} =
    ## $name: hello_namechange
    return  51

proc multiply(secondFactor: int) {.command.} =
    return 5 * secondFactor

proc countWord(word: string) {.command.} =
    return len(word)

proc channelTest(channel: Channel) {.command.} =
    echo channel
    return parseInt(channel)

proc testCommands(cmdName: string, cmdInput: string = ""): int =
    buildCommandTree(ctChatCommand)


static:
    # Compile time tests to make sure that the commands are added
    doAssert dimscordCommands.len >= 1
    doAssert dimscordCommands[0].help == "I return 50"

#
# Tests
#


test "The command tree is not available at runtime":
    check dimscordCommands.len == 0

test "The correct command can be called":
    check testCommands("test") == 50

test "Commands can have different names compared to the proc":
    check testCommands("hello_namechange") == 51

test "Parsing of int input":
    check testCommands("multiply", "5") == 25

test "Parsing of string input":
    check testCommands("countWord", "foobar") == 6

test "Parsing of word instead of sentence":
    check testCommands("countWord", "foobar hello") == 6

test "Help message generation":
    check generateHelpMsg() == "test: I return 50"

test "Token matching":
    let tokens = findTokens(" foo     bar! hello world ")
    check tokens[0] == "foo"
    check tokens[1] == "bar!"
    check tokens[2] == "hello"
    check tokens[3] == "world"
    check tokens.len() == 4

#test "Channel parameter parsing":
#    check testCommands("channelTest") == 1

test "Gettings command components":
    let components = getCommandComponents("!!", "!! Hello world foo")
    check components.name == "Hello"
    check components.input == "world foo"

