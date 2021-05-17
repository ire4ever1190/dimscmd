import unittest
import dimscmd
import asyncdispatch
import dimscord
include dimscmd/scanUtils
include dimscmd/parser
import strscans
import strutils
import options

const token = readFile("token").strip()
let discord = newDiscordClient(token, restMode = true)


test "Skipping past whitespace":
    let parser = newParser("     hello world")
    parser.skipWhitespace()
    check parser.input[parser.index] == 'h'

suite "Integer":
    let parser = newParser("6 hello")
    test "parsing":
        check parser.nextInt() == 6

    test "Error":
        expect ParserError:
            discard parser.nextInt()

suite "Boolean":
    let parser = newParser("true false yes no 1 0 cringe")
    test "true/false":
        check parser.nextBool()
        check not parser.nextBool()
    test "yes/no":
        check parser.nextBool()
        check not parser.nextBool()
    test "1/0":
        check parser.nextBool()
        check not parser.nextBool()
    test "else":
        expect ParserError:
            discard parser.nextBool()

suite "String":
    let parser = newParser("hello world ")
    test "parsing":
        check parser.nextString() == "hello"
        check parser.nextString() == "world"

    test "Empty":
        expect ParserError:
            discard parser.nextString()

suite "Discord Channel":
    test "Parsing":
        let parser = newParser("<#479193574341214210>", discord.api)
        let channel = waitFor parser.nextChannel()
        check channel.id == "479193574341214210"

suite "Sequence parsing":
    test "Integers":
        let parser = newParser("1 2 3 4 5")
        check parser.nextSeq(nextInt) == @[1, 2, 3, 4, 5]

    test "Booleans":
        let parser = newParser("yes false 0 1 true")
        check parser.nextSeq(nextBool) == @[true, false, false, true, true]

    test "Strings":
        let parser = newParser("hello world joe")
        check parser.nextSeq(nextString) == @["hello", "world", "joe"]

    test "Channels":
        let parser = newParser("<#479193574341214210> <#479193924813062152> <#744840686821572638>", discord.api)
        proc getChannels(): Future[seq[GuildChannel]] {.async.} =
            result = await parser.nextSeq(nextChannel)

        let channels = waitFor getChannels()
        check:
            channels[0].id == "479193574341214210"
            channels[1].id == "479193924813062152"
            channels[2].id == "744840686821572638"

    test "different types":
        let parser = newParser("1 2 3 hello world")
        check parser.nextSeq(nextInt) == @[1, 2, 3]
        check parser.nextSeq(nextString) == @["hello", "world"]
