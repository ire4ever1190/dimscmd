import unittest

include dimscmd

proc test(): int {.command.} =
    ## I return 50
    return 50

proc hello() {.ncommand(name = "hello_namechange").} =
    return  51

proc multiply(secondFactor: int) {.command.} =
    return 5 * secondFactor

proc countWord(word: string) {.command.} =
    return len(word)

proc testCommands(cmdName: string, cmdInput: string = ""): int =
    buildCommandTree()

static:
    # Compile time tests to make sure that the commands are added
    doAssert dimscordCommands.len >= 1
    doAssert dimscordCommands[0].help == "I return 50"

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

test "Help message generation":
    check generateHelpMsg() == "test: I return 50"
