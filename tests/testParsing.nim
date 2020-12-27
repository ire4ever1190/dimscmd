import parsing
import unittest
import macros
    
#[
    proc foo() = 
        ## $foo: bar
        ## $hello: world
        ## ====
        discard
]#

let fooProc {.compileTime.} = nnkProcDef.newTree(
    newIdentNode("foo"),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newEmptyNode()
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      newCommentStmtNode("$foo: bar\n$hello: world\n===="),
      nnkDiscardStmt.newTree(
        newEmptyNode()
      )
    )
  )


test "Parsing options from a string":
    let options = parseOptions """
        $foo:bar
        $hello:world
    """
    check options["foo"]   == "bar"
    check options["hello"] == "world"

static:
    # Test parsing options from a proc
    let options = parseOptions fooProc
    doAssert options["foo"]   == "bar"
    doAssert options["hello"] == "world"   
