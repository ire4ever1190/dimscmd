## Extra scanners for strscans module are defined in here
## Their job is to scan for dimscord objects like a channel, user, or role
# from dimscord/objects import Channel

proc channelScan(input: string, channelVar: var string, start: int): int =
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
    channelVar = channelID
    result = i

