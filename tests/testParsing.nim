import unittest
import dimscmd
import asyncdispatch
import dimscord
include dimscmd/scanUtils
import strscans
import strutils
import options

const token = readFile("token").strip()
let discord = newDiscordClient(token, restMode = true)


test "Skipping past a token":
    let input = "Hello world it is long"
    check scanfSkipToken(input, 0, "world") == 11


suite "Parsing discord types":
    # Don't worry if these fails
    # Since this requires an actual bot in an actual server, it will not work on your machine unless you change these values
    # or you have my test bot token
    test "Channel mention":
        let input = "<#479193574341214210>"
        var channel: Future[GuildChannel]
        let msg = Message(guildID: some "479193574341214208")
        check scanf(input, "${channelScan(discord.api)}", channel)
        check (waitFor channel).id == "479193574341214210"

    # test "User mention"
        # let input =

suite "Check string type":
    test "String":
        check "hello".isKind(string)

    test "Int":
        check "1234".isKind(int)
        check not "12g3".isKind(int)

    test "Channel":
        check "<#479193924813062152>".isKind(Future[Channel])

    test "User":
        check "<@259999449995018240>".isKind(Future[User])

    test "User with nickname":
        check "<@!259999449995018240>".isKind(Future[User])
        check not "<@&259999449995018240>".isKind(Future[User])
        

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
