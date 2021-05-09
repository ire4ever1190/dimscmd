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
    check scanfSkipToken("Hello world it is long", 0, "world") == 11
    check scanfSkipToken("helloworlditislong", 0, "world") == 10

test "Optional token":
    check optionalSkip("!Hello world", 0, '!') == 1
    check optionalSkip("Hello world", 0, '!') == 0
    check "Hello world".scanf("$[optionalSkip('!')]")
    var
        hello: string
        world: string
    check "!Hello world".scanf("$[optionalSkip('!')]$w $w", hello, world)
    check:
        hello == "Hello"
        world == "world"

test "Getting string scan symbols":
    check:
        getStrScanSymbol("string") == "$w"
        getStrScanSymbol("seq[string]") == "${seqScan[string](discord.api)}"
        getStrScanSymbol("Future[GuildChannel]") == "${channelScan(discord.api)}"
        getStrScanSymbol("seq[Future[GuildChannel]]") == "${seqScan[Future[GuildChannel]](discord.api)}"

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

suite "Parsing a sequence":
    test "Strings":
        let input = "foo bar hello world"
        var words: seq[string]
        check scanf(input, "${seqScan[string](discord.api)}", words)
        check words == @["foo", "bar", "hello", "world"]

    test "Ints":
        let input = "123 5 44"
        var nums: seq[int]
        check:
            scanf(input, "${seqScan[int](discord.api)}", nums)
            nums == @[123, 5, 44]

    test "Channel mentions":
        let input =  "<#479193574341214210> <#479193924813062152> <#744840686821572638>"
        var channels: seq[Future[GuildChannel]]
        check:
            input.scanf("${seqScan[Future[GuildChannel]](discord.api)}", channels)
            channels.len() == 3
            (waitFor channels[0]).id == "479193574341214210"
            (waitFor channels[1]).id == "479193924813062152"
            (waitFor channels[2]).id == "744840686821572638"
