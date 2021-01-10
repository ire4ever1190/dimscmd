import parsing
import unittest
import dimscmd

test "Skipping past a token":
    let input = "Hello world it is long"
    check scanfSkipToken(input, 0, "world") == 11