import unittest
import dimscmd/common

var rootNode = newGroup("", "")

test "Mapping a command":
    let cmd = Command(names: @["sum"])
    rootNode.map(["calc", "simple"], cmd)
    # Check if it works for base case
    check rootNode.children[0].name == "calc"
    # Now do proof by induction (joke)
    var currentNode = rootNode
    for i in 0..<3:
        check currentNode.children.len == 1
        if i != 3: currentNode = currentNode.children[0]

test "Flattening":
    let flattenedTree = rootNode.flatten()
    check flattenedTree.len == 1

test "No space at start of group name":
    let flattenedTree = rootNode.flatten()
    check flattenedTree[0].groupName == "calc simple sum"

test "Has key":
    check rootNode.has(["calc", "simple"])
    check rootNode.has(["calc", "simple", "sum"])
    check not rootNode.has(["calc", "test", "hello"])

test "Getting a command":
    let cmd = rootNode.get(["calc", "simple", "sum"])
    check cmd.name == "sum"

test "Aliasing":
    let cmd = Command(names: @["sum", "s"])
    rootNode.map(["calc", "complex"], cmd)
    check rootNode.has(["calc", "complex", "sum"])
    check rootNode.has(["calc", "complex", "s"])