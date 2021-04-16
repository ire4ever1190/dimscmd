## Extra scanners for strscans module are defined in here
## Their job is to scan for dimscord objects like a channel, user, or role
import asyncdispatch
import dimscord
import options
import strutils
import strscans

const
    patternChannel = "<#$i>"
    patternUser    = "<@$[optionScan('!')]$i>"

proc channelScan*(input: string, channelVar: var Future[GuildChannel], start: int, api: RestApi): int =
    ## Used with scanf macro in order to parse a channel from a string.
    ## This doesn't return a channel object but instead returns the Channel ID which gets the channel object later.
    ## This is because to resolve the channel ID into a channel I need to run async code and strscans cant run async code
    # Looks like: <#479193574341214210>
    if input[start .. start + 1] != "<#": return 0
    
    var
        i = 2
        channelID = ""

    while start + i < input.len and input[start + i] in {'0'..'9'}:
        channelID &= input[start + i]
        inc i
    if input[start + i] == '>':
        channelVar = api.getChannel(channelID)
        result = i
    else:
        result = 0

proc optionScan*(input: string, start: int, optionalChar: char): int =
    
    result = if input[start] == optionalChar:
        1
    else:
        0
    

proc isKind[T](x: string, t: typedesc[T]): bool =
    ## Checks if x is parsable has type T
    # Is this the best method of doing things?
    when T is string:
        result = true # string can be anything

    elif T is int:
        result = true
        for char in x:
            if 48 > char.ord or char.ord > 57: # Check if every character is a number
                return false
                    
    elif T is Future[Channel]:
        var channelID: int
        result = x.scanf(patternChannel, channelID)

    elif T is Future[User]:
        var userID: int
        result = x.scanf(patternUser, userID)  
    
proc seqScan*[T](input: string, items: var seq[T], start: int): int =
    ## Scans a sequence of tokens from within a string of a certain type
    
    var i = 0

    while start + i < input.len:
        var currentToken = ""
        while start + i < input.len and input[start + i] != ' ':
            currentToken &= input[start + i]
            inc i
        # Check if the found token is of type T
        # If it is then it parses it from a string to type T
        # If it isn't then it breaks and removes the last token from the scanned amount
        if currentToken.isKind(T):
            # Different types need to be converted in different ways
            when T is string:
                items &= currentToken
            elif T is int:
                items &= currentToken.parseInt()
            elif T is Future[GuildChannel]:
                var channelID: int
                discard scanf(patternChannel, channelID)
                # items &=
            elif T is Future[User]:
                var userID: int
                discard scanf(patternUser)
            
            inc i # Go past space
        else:
            result = i - currentToken.len()
            break

    result = i
            
proc scanfSkipToken*(input: string, start: int, token: string): int =
    ## Skips to the end of the first found token. The token can be found in the middle of a string e.g.
    ## The token `hello` can be found in foohelloworld
    ## Returns 0 if the token was not found
    var index = start
    template notWhitespace(): bool = not (input[index] in Whitespace)
    while index < input.len:
        if index < input.len and notWhitespace:
            let identStart = index
            for character in token: # See if each character in the token can be found in sequence 
                if input[index] == character:
                    inc index
            let ident = substr(input, identStart, index - 1)
            if ident == token:
                return index - start
        inc index
