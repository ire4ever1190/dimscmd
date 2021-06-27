import std/[
    parseutils,
    strutils
]
proc getWords*(input: string): seq[string] =
    ## Splits the input string into each word
    ## Handles multple spaces
    var i = 0
    while i < input.len:
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