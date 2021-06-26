import unittest
import dimscmd/common

var rootNode = newGroup("", "")

test "Mapping a command":
    let cmd = Command(name: "sum")
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

test "Getting a command":
    let cmd = rootNode.get(["calc", "simple", "sum"])
    check cmd.name == "sum"