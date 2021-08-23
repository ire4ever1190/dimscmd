import dimscmd/utils
import std/unittest

test "getWords":
    check "calc sum".getWords() == @["calc", "sum"]

test "leafName":
    check "calc sum".leafName() == "sum"
    check "sum".leafName() == "sum"