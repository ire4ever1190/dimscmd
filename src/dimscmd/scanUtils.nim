## Extra scanners for strscans module are defined in here
## Their job is to scan for dimscord objects like a channel, user, or role
import asyncdispatch
import dimscord
import options
import strutils
import strscans
import strformat

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
    ## TODO replace this with scanf to reduce all the effort I have to do
    while start + i < input.len and input[start + i] in {'0'..'9'}:
        channelID &= input[start + i]
        inc i
    if input[start + i] == '>':
        channelVar = api.getChannel(channelID)
        result = i
    else:
        result = 0

proc optionScan*(input: string, start: int, optionalChar: char): int =
    ## Can skip an optional character
    result = if input[start] == optionalChar:
        1
    else:
        0

proc scanfSkipToken*(input: string, start: int, token: string): int =
    ## Skips to the end of the first found token. The token can be found in the middle of a string e.g.
    ## The token `hello` can be found in foohelloworld
    ## Returns 0 if the token was not found
    template notWhitespace(): bool = not (input[index] in Whitespace)
    result = input.find(token, start = start)
    if result == -1:
        result = 0
    else:
        result += token.len() # Add the length of the token so it goes to the final letter
    echo input
    echo "Skipping ", token, " ", result

proc getStrScanSymbol*(typ: string): string =
    ## Gets the symbol that strscan uses in order to parse something of a certain type
    var 
        outer = "" # The value outside the square brackets e.g. seq[int], seq is the outer
        inner = "" # The value inside the square brackets e.g. seq[int], int is the inner
    discard scanf(typ.replace("objects.", ""), "$w[$w]", outer, inner)
    echo "outer ", outer, " inner ", inner
    case outer:
        of "int": "$i"
        of "string": "$w"
        of "Channel", "GuildChannel": "${channelScan(discord.api)}"
        of "seq": "${seqScan[" & inner & "]()}"
        of "Future":
            getStrScanSymbol(inner)
        else: ""

    
proc seqScan*[T](input: string, items: var seq[T], start: int): int =
    ## Scans a sequence of tokens from within a string of a certain type
    var i = 0
    const pattern = getStrScanSymbol($T) # TODO check if it is a sequence, don't know how a 2d array would work in a message
    while start + i < input.len:
        var currentToken = ""
        while start + i < input.len and input[start + i] != ' ':
            currentToken &= input[start + i]
            inc i

        var token: T
        
        if currentToken.scanf(pattern, token):
            items &= token
            inc i
        else:
            result = i - currentToken.len()

    result = i
