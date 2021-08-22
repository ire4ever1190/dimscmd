import unittest
import dimscmd/common

var rootNode = newGroup("", "")

test "Mapping a command":
    let cmd = Command(names: @["ping"])
    rootNode.map(cmd)
    check rootNode.children[0].name == "ping"

test "Mapping a sub command":
    let cmd = Command(names: @["calc simple sum"])
    rootNode.map(cmd)
    # Check if it works for base case
    check rootNode.children[1].name == "calc"


test "Flattening":
    let flattenedTree = rootNode.flatten()
    check flattenedTree.len == 2

test "No space at start of group name":
    let flattenedTree = rootNode.flatten()
    check flattenedTree[0].name == "calc simple sum"

test "Has key":
    check rootNode.has(["calc", "simple"])
    check rootNode.has(["calc", "simple", "sum"])
    check not rootNode.has(["calc", "test", "hello"])

test "Getting a command":
    let cmd = rootNode.get(["calc", "simple", "sum"])
    check cmd.name == "calc simple sum"

suite "Aliasing":
    test "Basic aliasing":
        let cmd = Command(names: @["calc complex sum"])
        rootNode.map(cmd)
        rootNode.mapAltPath(
            ["calc", "complex", "sum"],
            ["calc", "complex", "s"]
        )
        check rootNode.has(["calc", "complex", "sum"])
        check rootNode.has(["calc", "complex", "s"])

    test "Different entirely":
        rootNode.mapAltPath(
            ["calc", "simple", "sum"],
            ["do", "sum"]
        )
        check rootNode.has(["calc", "simple", "sum"])
        check rootNode.has(["do", "sum"])
        let
            a = rootNode.get(["calc", "simple", "sum"])
            b = rootNode.get(["do", "sum"])
        check a == b

