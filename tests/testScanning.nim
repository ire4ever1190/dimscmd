import unittest
import dimscmd
import asyncdispatch
import dimscord
include dimscmd/scanner
import strscans
import strutils
import options

const token = readFile("token").strip()
let discord = newDiscordClient(token, restMode = true)


test "Skipping past whitespace":
    let scanner = newScanner("     hello world")
    scanner.skipWhitespace()
    check scanner.input[scanner.index] == 'h'

suite "Integer":
    let scanner = newScanner("6 hello")
    test "scanning":
        check scanner.nextInt() == 6

    test "Error":
        expect ScannerError:
            discard scanner.nextInt()

suite "Boolean":
    let scanner = newScanner("true false yes no 1 0 cringe")
    test "true/false":
        check scanner.nextBool()
        check not scanner.nextBool()
    test "yes/no":
        check scanner.nextBool()
        check not scanner.nextBool()
    test "1/0":
        check scanner.nextBool()
        check not scanner.nextBool()
    test "else":
        expect ScannerError:
            discard scanner.nextBool()

suite "String":
    let scanner = newScanner("hello world ")
    test "scanning":
        check scanner.nextString() == "hello"
        check scanner.nextString() == "world"

    test "Empty":
        expect ScannerError:
            discard scanner.nextString()

suite "Discord Channel":
    test "Scanning":
        let scanner = newScanner("<#479193574341214210>", discord.api)
        let channel = waitFor scanner.nextChannel()
        check channel.id == "479193574341214210"

    test "Invalid Channel":
        expect ScannerError:
            let scanner = newScanner("<#47919357434>", discord.api)
            let channel = waitFor scanner.nextChannel()

suite "Discord Role":
    test "Scanning":
        let scanner = newScanner(
            discord.api,
            Message(content: "<@&483606693180342272>", guildID: some "479193574341214208")
        )
        let role = waitFor scanner.nextRole()
        check role.name == "Supreme Ruler"

    test "Invalid Role":
        expect ScannerError:
            let scanner = newScanner("<@&48360669318>", discord.api)
            discard waitFor scanner.nextRole()

suite "Discord User":
    test "Scanning":
        let scanner = newScanner("<@!742010764302221334>", discord.api)
        let user = waitFor scanner.nextUser()
        check user.username == "Kayne"

    test "Invalid User":
        expect ScannerError:
            let scanner = newScanner("<@!74201064302221334>", discord.api)
            discard waitFor scanner.nextUser()


suite "Sequence scanning primitives":
    test "Integers":
        let scanner = newScanner("1 2 3 4 5")
        check scanner.nextSeq(nextInt) == @[1, 2, 3, 4, 5]

    test "Booleans":
        let scanner = newScanner("yes false 0 1 true")
        check scanner.nextSeq(nextBool) == @[true, false, false, true, true]

    test "Strings":
        let scanner = newScanner("hello world joe")
        check scanner.nextSeq(nextString) == @["hello", "world", "joe"]

    test "different types":
        let scanner = newScanner("1 2 3 hello world")
        check scanner.nextSeq(nextInt) == @[1, 2, 3]
        check scanner.nextSeq(nextString) == @["hello", "world"]

suite "Sequence scanning discord types":
    # I shouldn't test both individual seqs and group seqs at the same time but I'm lazy
    let scanner = discord.api.newScanner(Message(
            content: "<#479193574341214210> <#479193924813062152> <#744840686821572638> " &
                     "<@!742010764302221334> <@!259999449995018240> " &
                     "<@&483606693180342272> <@&843738308374691860>",
            guildID: some "479193574341214208"
        ))

    test "Channels":
        let channels = waitFor scanner.nextSeq(nextChannel)
        check:
            channels[0].id == "479193574341214210"
            channels[1].id == "479193924813062152"
            channels[2].id == "744840686821572638"

    test "Users":
        let users = waitFor scanner.nextSeq(nextUser)
        check:
            users[0].username == "Kayne"
            users[1].username == "amadan"

    test "Roles":
        let roles = waitFor scanner.nextSeq(nextRole)
        check:
            roles[0].name == "Supreme Ruler"
            roles[1].name == "Bot"
