import dimscmd/utils
import std/unittest

test "getWords":
    check "calc sum".getWords() == @["calc", "sum"]
