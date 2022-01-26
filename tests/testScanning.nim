import unittest
import dimscmd
import asyncdispatch
import dimscord
include token
include dimscmd/scanner
import strscans
import strutils
import options

let discord = newDiscordClient(token, restMode = true)

type
    Colour = enum
        Red
        Green
        Blue

test "Skipping past whitespace":
    let scanner = newScanner("     hello world")
    scanner.skipWhitespace()
    check scanner.input[scanner.index] == 'h'

suite "Integer":
    let scanner = newScanner("6 hello")
    test "scanning":
        check scanner.next(int) == 6

    test "Error":
        expect ScannerError:
            discard scanner.next(int)

suite "Boolean":
    let scanner = newScanner("true false yes no 1 0 cringe")
    test "true/false":
        check scanner.next(bool)
        check not scanner.next(bool)
    test "yes/no":
        check scanner.next(bool)
        check not scanner.next(bool)
    test "1/0":
        check scanner.next(bool)
        check not scanner.next(bool)
    test "else":
        expect ScannerError:
            discard scanner.next(bool)

suite "String":
    let scanner = newScanner("hello world ")
    test "scanning":
        check scanner.next(string) == "hello"
        check scanner.next(string) == "world"

    test "Empty":
        expect ScannerError:
            discard scanner.next(string)

suite "Enum":
    let scanner = newScanner("red grEEn blue shrek")
    test "Scanning":
        check scanner.next(Colour) == Colour.Red
        check scanner.next(Colour) == Colour.Green
        check scanner.next(Colour) == Colour.Blue

    test "Not an enum":
        expect ScannerError:
            discard scanner.next(Colour)


suite "Discord Channel":
    test "Scanning":
        let scanner = newScanner("<#479193574341214210>", discord.api)
        let channel = waitFor scanner.next(Future[GuildChannel])
        check channel.id == "479193574341214210"

    test "Invalid Channel":
        expect ScannerError:
            let scanner = newScanner("<#47919357434>", discord.api)
            let channel = waitFor scanner.next(Future[GuildChannel])

suite "Discord Role":
    test "Scanning":
        let scanner = newScanner(
            discord.api,
            Message(content: "<@&483606693180342272>", guildID: some "479193574341214208")
        )
        let role = waitFor scanner.next(Role)
        check role.name == "Supreme Ruler"

    test "Invalid Role":
        expect ScannerError:
            let scanner = newScanner("<@&48360669318>", discord.api)
            discard waitFor scanner.next(Future[Role])

suite "Discord User":
    test "Scanning":
        let scanner = newScanner("<@!742010764302221334>", discord.api)
        let user = waitFor scanner.next(Future[User])
        check user.username == "Kayne"

    test "Invalid User":
        expect ScannerError:
            let scanner = newScanner("<@!74201064302221334>", discord.api)
            discard waitFor scanner.next(Future[User])


suite "Sequence scanning primitives":
    test "Integers":
        let scanner = newScanner("1 2 3 4 5")
        check scanner.next(seq[int]) == @[1, 2, 3, 4, 5]

    test "Booleans":
        let scanner = newScanner("yes false 0 1 true")
        check scanner.next(seq[bool]) == @[true, false, false, true, true]

    test "Strings":
        let scanner = newScanner("hello world joe")
        check scanner.next(seq[string]) == @["hello", "world", "joe"]

    test "different types":
        let scanner = newScanner("1 2 3 hello world")
        check scanner.next(seq[int]) == @[1, 2, 3]
        check scanner.next(seq[string]) == @["hello", "world"]

suite "Range types":
    let scanner = newScanner("3 10 1")
    test "In range":
        check scanner.next(range[2..5]) == 3
    test "Out of range":
        expect ScannerError:
            check scanner.next(range[2..5]) == 10
        

suite "Sequence scanning discord types":
    # I shouldn't test both individual seqs and group seqs at the same time but I'm lazy
    let scanner = discord.api.newScanner(Message(
            content: "<#479193574341214210> <#479193924813062152> <#744840686821572638> " &
                     "<@!742010764302221334> <@!259999449995018240> " &
                     "<@&483606693180342272> <@&843738308374691860>",
            guildID: some "479193574341214208"
        ))

    test "Channels":
        let channels = waitFor scanner.next(Future[seq[GuildChannel]])
        check:
            channels[0].id == "479193574341214210"
            channels[1].id == "479193924813062152"
            channels[2].id == "744840686821572638"

    test "Users":
        let users = waitFor scanner.next(Future[seq[User]])
        check:
            users[0].username == "Kayne"
            users[1].username == "amadan"

    test "Roles":
        let roles = waitFor scanner.next(Future[seq[Role]])
        check:
            roles[0].name == "Supreme Ruler"
            roles[1].name == "Bot"

test "Optional scanning":
    let scanner = newScanner("hello")
    check not scanner.next(Option[int]).isSome()
    check scanner.next(Option[string]).get() == "hello"

test "Optional scanning discord type":
        let scanner = newScanner("<@!742010764302221334>", discord.api)
        let user = waitFor scanner.next(Future[Option[User]])
        check user.isSome()
        check user.get().username == "Kayne"
