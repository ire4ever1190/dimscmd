import std/parseutils
import std/strformat
import std/strutils
import std/options
import std/asyncdispatch
import std/strscans
import dimscord

type
    CommandScanner* = ref object
        api: RestApi
        message: Message
        index*: int

    ScannerError* = object of ValueError

proc input(scanner: CommandScanner): string =
    result = scanner.message.content

proc newScanner*(input: string, api: RestApi = nil): CommandScanner =
    result = CommandScanner(
        api: api,
        message: Message(content: input),
        index: 0
    )

proc showCurrentSpot(scanner: CommandScanner): string =
    result = scanner.input & "\n"
    result &= " ".repeat(scanner.index) & "^"

proc newScanner*(api: RestApi, msg: Message): CommandScanner =
    result = CommandScanner(
        api: api,
        message: msg,
        index: 0
    )

proc hasMore*(scanner: CommandScanner): bool =
    result = scanner.index < scanner.input.len()

proc getGuildRole(api: RestApi, gid, id: string): Future[Role] {.async.} =
    ## Gets the role from a guild with specific id
    let roles = await api.getGuildRoles(gid)
    for role in roles:
        if role.id == id:
            return role

proc skipWhitespace(scanner: CommandScanner) =
    ## Skips past whitespace and sets the current index to the character that follows
    ## Is ran before every other parsing function so it should not be called manually
    scanner.index += scanner.input.skipWhitespace(scanner.index)

proc skipPast*(scanner: CommandScanner, token: string) =
    let length = scanner.input.find(token, start = scanner.index)
    if length == -1:
        scanner.index = 0
    else:
        scanner.index = length + token.len()

proc nextToken(scanner: CommandScanner): string =
    ## Gets the next token
    scanner.index += scanner.input.parseUntil(result, ' ', scanner.index)

proc nextInt*(scanner: CommandScanner): int =
    ## Parses the next available integer
    scanner.skipWhitespace()
    let processedChars = scanner.input.parseInt(result, scanner.index)
    if processedChars == 0:
        var token: string
        discard scanner.input.parseUntil(token, ' ', start = scanner.index)
        scanner.index += token.len
        raise newException(ScannerError, fmt"Expected number but got {token}")
    else:
        scanner.index += processedChars

proc nextBool*(scanner: CommandScanner): bool =
    ## Parses the next boolean value.
    ## Possible values for true are
    ##      - true
    ##      - yes
    ##      - 1
    ## possible values for false are
    ##      - false
    ##      - yes
    ##      - 0
    scanner.skipWhitespace()
    let token = scanner.nextToken()
    result = case token.toLowerAscii():
        of "true", "1", "yes":
            true
        of "false", "0", "no":
            false
        else:
            raise newException(ScannerError, fmt"Excepted true/false value but got {token}")

proc nextString*(scanner: CommandScanner): string =
    scanner.skipWhitespace()
    result = scanner.nextToken()
    if result.len() == 0:
        raise newException(ScannerError, "Expected a token but got nothing")

proc nextChannel*(scanner: CommandScanner): Future[GuildChannel] {.async.} =
    scanner.skipWhitespace()
    var channelID: int
    let token = scanner.nextToken()
    if token.scanf("<#$i>", channelID) and len($channelID) == 18:
        let chan = await scanner.api.getChannel($channelID)
        if chan[0].isSome():
            result = chan[0].get()
        else:
            raise newException(ScannerError, fmt"{channelID} is not a valid channel (-)")
    else:
        raise newException(ScannerError, fmt"{token} is not a proper channel (-)")

proc nextRole*(scanner: CommandScanner): Future[Role] {.async.} =
    scanner.skipWhitespace()
    var roleID: int
    let token = scanner.nextToken()
    if token.scanf("<@&$i>", roleID) and len($roleID) == 18:
        result = await scanner.api.getGuildRole(scanner.message.guildID.get(), $roleID)
    else:
        raise newException(ScannerError, fmt"{token} is not a proper role ID (-)")

proc nextUser*(scanner: CommandScanner): Future[User] {.async.} =
    scanner.skipWhitespace()
    var userID: int
    let token = scanner.nextToken().replace("!", "")
    if token.scanf("<@$i>", userID) and len($userID) == 18:
        result = await scanner.api.getUser($userID)
    else:
        raise newException(ScannerError, fmt"{token} is not a proper userID (-)")

template nextSeqBody(nextTokenCode: untyped): untyped =
    ## Scans a sequence of values by continuely running the scanProc until there are no more values to parse
    ## or if it runs into a value of a different type
    bind hasMore
    while hasMore(scanner):
        var next: T
        let oldIndex = scanner.index
        try:
            next = nextTokenCode
        except ScannerError:
            scanner.index = oldIndex
            break
        result &= next
    if result.len() == 0:
        raise newException(ScannerError, "No values were able to be parsed (-)")

proc nextSeq*[T](scanner: CommandScanner, scanProc: proc (scanner: CommandScanner): T): seq[T] =
    nextSeqBody(scanner.scanProc())

proc nextSeq*[T](scanner: CommandScanner, scanProc: proc (scanner: CommandScanner): Future[T]): Future[seq[T]] {.async.} =
    nextSeqBody(await scanner.scanProc())

template nextOptionalBody(nextTokenCode: untyped): untyped =
    let oldIndex = scanner.index
    try:
        result = some nextTokenCode
    except ScannerError:
        result = none T
        scanner.index = oldIndex

proc nextOptional*[T](scanner: CommandScanner, scanProc: proc (scanner: CommandScanner): T): Option[T] =
    nextOptionalBody(scanner.scanProc())

proc nextOptional*[T](scanner: CommandScanner, scanProc: proc (scanner: CommandScanner): Future[T]): Future[Option[T]] {.async.} =
    nextOptionalBody(await scanner.scanProc())

