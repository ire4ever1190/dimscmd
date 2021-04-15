## Extra scanners for strscans module are defined in here
## Their job is to scan for dimscord objects like a channel, user, or role
import asyncdispatch
import dimscord
import options
import strutils

proc getGuildChannel(api: RestApi, gid, id: string): Future[GuildChannel] {.async.} =
  when libVer == "1.2.7":
    let chan = await api.getChannel(id)
    if chan[0].isSome:
      return chan[0].get
    else:
      raise newException(Exception, "Invalid guild channel.")
  else:
    return await api.getGuildChannel(gid, id) # This procedure is broken, however 1.2.7 fixes this issue.

proc channelScan*(input: string, channelVar: var Future[GuildChannel], start: int, api: RestApi, m: Message): int =
    ## Used with scanf macro in order to parse a channel from a string.
    ## This doesn't return a channel object but instead returns the Channel ID which gets the channel object later.
    ## This is because to resolve the channel ID into a channel I need to run async code and strscans cant run async code
    # Looks like: #479193574341214210>
    # Don't know why the first < is removed
    if input[0] != '#': return 0
    var
        i = 1
        channelID = ""

    while start + i < input.len and input[start + i] in {'0'..'9'}:
        channelID &= input[start + i]
        inc i

    echo "Channel ID, ", channelID
    echo "Guild ID,   ", m.guildID.get()
    
    channelVar = api.getGuildChannel(m.guildID.get(), channelID)
    result = i

proc isKind(x: string, T: typedesc): bool =
    ## Checks if x is like T in string form
    case $T:
        of "string":
            result = true # string can be anything
        of "int":
            result = true
            for char in x:
                if 48 > char.ord or char.ord > 57: # Check if every character is a number
                    return false
            
proc seqScan*[T](input: string, items: var seq[T], start: int): int =
    ## Scans a sequence of tokens from within a string of a certain type
    
    var i = 0

    while start + i < input.len:
        var currentToken = ""
        while start + i < input.len and input[start + i] != ' ':
            currentToken &= input[start + i]
            inc i
        if currentToken.isKind(T):
            # Different types need to be converted in different ways
            when T is string:
                items &= currentToken
            elif T is int:
                items &= currentToken.parseInt()
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
