import unittest
import dimscmd
import asyncdispatch
import dimscord
include dimscmd/discordScans
import strscans
import strutils
import options

const token = readFile("token").strip()
let discord = newDiscordClient(token, restMode = true)


test "Skipping past a token":
    let input = "Hello world it is long"
    check scanfSkipToken(input, 0, "world") == 11

# test "Parsing a channel mention":
    # let input = "#479193574341214210>"
    # var channel: Future[GuildChannel]
    # let msg = Message(guildID: some "479193574341214208")
    # # I'll get back to this
    # check false
    # # check scanf(input, "${channelScan(discord.api, msg)}", channel)
    # # check (waitFor channel).id == "479193924813062152"

suite "Check string type":
    test "String":
        check "hello".isKind(string)

    test "Int":
        check "1234".isKind(int)
        check not "12g3".isKind(int)

suite "Parsing a sequence":
    test "Strings":
        let input = "foo bar hello world"
        var words: seq[string]
        check scanf(input, "${seqScan[string]()}", words)
        check words == @["foo", "bar", "hello", "world"]

    test "Ints":
        let input = "123 5 44"
        var nums: seq[int]
        check:
            scanf(input, "${seqScan[int]()}", nums)
            nums == @[123, 5, 44]
