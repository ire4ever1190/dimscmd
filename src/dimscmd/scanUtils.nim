## Extra scanners for strscans module are defined in here
## Their job is to scan for dimscord objects like a channel, user, or role
import asyncdispatch
import dimscord
import options
import strutils
import strscans
import parseutils
import strformat

const
    patternChannel = "<#$i>"
    patternUser    = "<@$[optionalSkip('!')]$i>"
    patternRole    = "<@&$i>"

type
    DiscordParsingError = object of ValueError
    InvalidChannel = object of DiscordParsingError
    InvalidUser    = object of DiscordParsingError
    InvalidRole    = object of DiscordParsingError

proc getGuildChannelWrapper(api: RestApi, id: string): Future[GuildChannel] {.async.} =
    ## Gets the guild channel from the [GuildChannel, DmChannel] tuple
    let chan = await api.getChannel(id)
    if chan[0].isSome():
        result = chan[0].get()
    else:
        raise newException(InvalidChannel, fmt"{id} is not a valid channel")

proc getGuildRole(api: RestApi, gid, id: string): Future[Role] {.async.} =
    ## Gets the role from a guild with specific id
    let roles = await api.getGuildRoles(gid)
    for role in roles:
        if role.id == id:
            return role


proc optionalSkip*(input: string, start: int, optionalChar: char): int =
    ## Can skip an optional character
    result = if input[start] == optionalChar:
        1
    else:
        0 # I don't actually think this works since scanf procs can't return 0


proc channelScan*(input: string, channelVar: var Future[GuildChannel], start: int, api: RestApi): int =
    ## Used with scanf macro in order to parse a channel from a string
    # Looks like: <#479193574341214210>

    var channelID: int
    if input[start..^1].scanf(patternChannel, channelID):
        result = len($channelID) + 3 # Add in the length for <#>
        channelvar = api.getGuildChannelWrapper($channelID)
    else:
        raise newException(InvalidChannel, fmt"{input[start..^1]} does not start with a proper channel ID")

proc userScan*(input: string, userVar: var Future[User], start: int, api: RestApi): int =
    ## Used with scanf macro in order to parse a user from a string
    var userID: int
    if input[start..^1].scanf(patternUser, userID):
        result = len($userID) + 3 # Add in the length for <@>
        userVar = api.getUser($userID)
        if input[start + 2] == '!':
            inc result
    else:
        raise newException(InvalidUser, fmt"{input[start..^1]} does not start with a proper user ID")

proc roleScan*(input: string, roleVar: var Future[Role], start: int, api: RestApi, message: Message): int =
    ## Used with scanf macro in order to parse a role from a string
    # TODO find a way to not use message since it stops the user from being allowed to redefine stuff
    var roleID: int
    if input[start..^1].scanf(patternRole, roleID):
        result = len($roleID) + 3 # Add in the length for <@>
        roleVar = api.getGuildRole(message.guildID.get(), $roleID)
    else:
        raise newException(InvalidRole, fmt"{input[start..^1]} does not start with a proper role ID")

proc scanfSkipToken*(input: string, start: int, token: string): int =
    ## Skips to the end of the first found token. The token can be found in the middle of a string e.g.
    ## The token `hello` can be found in foohelloworld
    ## Returns 0 if the token was not found
    result = input.find(token, start = start)
    if result == -1:
        result = 0
    else:
        result += token.len() # Add the length of the token so it goes to the final letter

proc getStrScanSymbol*(typ: string): string =
    ## Gets the symbol that strscan uses in order to parse something of a certain type
    # The value outside the square brackets e.g. seq[int], seq is the outer
    # The value inside the square brackets e.g. seq[int], int is the inner
    var
        outer: string
        inner: string
    # Parse the string until it encounters the first [ or gets to the end
    # If there is still more to parse the slice the string until the second last character
    let outerLength = typ.parseUntil(outer, '[')
    if outerLength < len(typ):
        inner = typ[outerLength + 1 .. ^2]
        inner.removePrefix("objects.")
        if inner.toLowerAscii() in ["channel", "guildchannel", "user", "role"] and outer == "seq":
            inner = "Future[" & inner & "]"

    case outer:
        of "int":     "$i"
        of "string":  "$w"
        of "Channel", "GuildChannel": "${channelScan(discord.api)}"
        of "User":    "${userScan(discord.api)}"
        of "Role":    "${roleScan(discord.api, msg)}"
        of "seq":     "${seqScan[" & inner & "](discord.api)}"
        of "Future":  getStrScanSymbol(inner)
        else: ""

    
proc seqScan*[T](input: string, items: var seq[T], start: int, api: RestApi): int =
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
            when T is Future[GuildChannel]:
                var channelFut: Future[GuildChannel]
                discard input.channelScan(channelFut, (start + i) - currentToken.len(), api)
                items &= channelFut
            elif T is Future[User]:
                var userFut: Future[User]
                discard input.userScan(userFut, (start + i) - currentToken.len(), api)
                items &= userFut
            else:
                items &= token
            inc i # Skip the space
        else:
            return i - currentToken.len()
    result = i
