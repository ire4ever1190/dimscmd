import std/[
    parseutils,
    strutils,
    macros
]

macro matchIdent*(id: string, body: untyped): untyped =
    ## Creates a case statement to match a string against
    ## other strings in style insensitive way
    let expression = nnkCall.newTree(
        bindSym("normalize"),
        id
    )
    result = nnkCaseStmt.newTree(expression)
    for node in body:
        node.expectKind(nnkCall)
        var ofBranch = nnkOfBranch.newTree()
        echo node.treeRepr
        template normalString(node: NimNode): untyped = node.strVal.normalize().newStrLitNode()
        if node[0].kind in {nnkTupleConstr, nnkPar}: # On devel it is nnkTupleConstr, stable it is nnkPar
            for value in node[0]:
                ofBranch.add normalString(value)
        else:
            ofBranch.add normalString(node[0])
        ofBranch.add node[1]
        result.add ofBranch
        # The else branch is embedded with an of branch for some reason.
        # This moves it into the case statement.
        if node[^1].kind == nnkElse:
            result.add node[^1]

proc getWords*(input: string): seq[string] =
    ## Splits the input string into each word
    ## Handles multple spaces
    var i = 0
    while i < input.len:
        # - Parse token until it reaches a whitespace character
        # - skip any whitespace that follows the token
        # - repeat til the end is reached
        var newWord: string
        i += input.parseUntil(newWord, Whitespace, start = i)
        i += input.skipWhitespace(start = i)
        result &= newWord

proc toKey*(input: string): seq[string] =
    ## Converts a string into a key for the command tree
    ## i.e It splits the input into each word and then returns every word except the last
    input.getWords()[0..^2] # Remove last word

proc leafName*(input: string): string =
    ## Returns the last word in a sentence
    input.getWords()[^1]

