import std/[
    parseutils,
    strutils,
    macros
]

{.experimental: "caseStmtMacros".}
macro match*(id: untyped): untyped =
    ## Case statement macro which allows style insensitive comparisons
    ## for identifiers. The of branches need to be strings, not idents
    # Convert to the call to call `normalize` instead of `ident`
    let newCall = nnkCall.newTree(
        bindSym("normalize"),
        id[0][1]
    )
    result = nnkCaseStmt.newTree(newCall)
    for i in 1..<id.len:
        let it = id[i]
        case it.kind
            of nnkElse, nnkElifBranch, nnkElifExpr, nnkElseExpr:
                result.add it
            of nnkOfBranch:
                for j in 0..it.len-2:
                    let normalisedName = it[j].strVal().normalize()
                    result.add nnkOfBranch.newTree(
                        normalisedName.newStrLitNode(),
                        it[^1]
                    )
            else:
                error "'match' cannot handle this node", it

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

