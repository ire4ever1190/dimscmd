import std/parseutils
import std/strformat
import std/strutils
import std/options
import std/asyncdispatch
import std/strscans
import std/macros
import discordUtils
import dimscord
import segfaults

type
    CommandScanner* = ref object
        api: RestApi
        message: Message
        index*: int

    ScannerError* = object of ValueError
        message*: string

template raiseScannerError*(msg: string) =
    ## Raises a scanner error with the msg parameter being the `message` attribute attached to the exception.
    ## This is so that the async stack trace is not added to the exception message
    var err: ref ScannerError
    new err
    err.message = msg
    raise err

macro scanProc*(prc: untyped): untyped =
    ## Adds in a type parameter to a proc to get a basic return type overloading
    ## e.g.
    ##
    ## .. code-block:: nim
    ##  proc next*(scanner: CommandScanner): int {.scanProc.}
    ##  # becomes
    ##  proc next*(scanner: CommandScanner, kind: typedesc[int]): int
    ##
    result = prc
    var params = prc.params
    var returnType = params[0]
    if returnType.kind == nnkBracketExpr and returnType[0] == "Future".ident():
        # If it is a future then add two possible overloads
        # scanner.next(T) or scanner.next(Future[T])
        # Done to work with seq/option
        returnType = nnkInfix.newTree(
            "|".ident(),
            returnType,
            returnType[1]
        )
    params.add nnkIdentDefs.newTree(
        "kind".ident(),
        nnkBracketExpr.newTree(
            newIdentNode("typedesc"),
            returnType
        ),
        newEmptyNode()
    )
    result.params = params

proc input*(scanner: CommandScanner): string =
    result = scanner.message.content

proc newScanner*(input: string, api: RestApi = nil): CommandScanner =
    result = CommandScanner(
        api: api,
        message: Message(content: input),
        index: 0
    )

proc showCurrentSpot(scanner: CommandScanner): string =
    ## used for debugging, adds a ^ to point to the current character
    result = scanner.input & "\n"
    result &= " ".repeat(scanner.index) & "^"

proc newScanner*(api: RestApi, msg: Message): CommandScanner =
    result = CommandScanner(
        api: api,
        message: msg,
        index: 0
    )

proc hasMore*(scanner: CommandScanner): bool =
    ## Return true if there are still characters left to check
    result = scanner.index < scanner.input.len()

proc skipWhitespace*(scanner: CommandScanner) =
    ## Skips past whitespace and sets the current index to the character that follows
    ## Is ran before every other parsing function so it should not be called manually
    scanner.index += scanner.input.skipWhitespace(scanner.index)

proc skipPast*(scanner: CommandScanner, token: string) =
    ## Skips the scanner past a token i.e sets the position of the scanner
    ## to be after the first occurance of `token`
    let length = scanner.input.find(token, start = scanner.index)
    if length == -1:
        scanner.index = 0
    else:
        scanner.index = length + token.len()

proc skipPast*(scanner: CommandScanner, tokens: seq[string]) =
    ## Finds the token that is closet to the beginning and skips past that
    var smallest: tuple[token: string, length: int] = ("", int.high)
    for token in tokens:
        let length = scanner.input.find(token, start = scanner.index)
        if length != -1 and length < smallest.length:
            smallest = (token, length)
    if smallest.token == "": # Nothing was found
        scanner.index = 0
    else:
        scanner.index = smallest.length + smallest.token.len

proc parseUntil*(scanner: CommandScanner, until: char): string =
    ## Scans a string until it reaches a character
    scanner.index += scanner.input.parseUntil(result, until, scanner.index)

proc nextToken*(scanner: CommandScanner): string =
    ## Gets the next token
    result = scanner.parseUntil(' ').strip()

proc next*(scanner: CommandScanner): int {.scanProc.} =
    ## Parses the next available integer
    scanner.skipWhitespace()
    let processedChars = scanner.input.parseInt(result, scanner.index)
    if processedChars == 0:
        let token = scanner.nextToken()
        scanner.index += token.len # whats this for?
        if token == "":
            raiseScannerError(fmt"Expected number but got nothing")
        else:
            raiseScannerError(fmt"Expected number but got {token}")
    else:
        scanner.index += processedChars

proc next*(scanner: CommandScanner): bool {.scanProc.} =
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
            raiseScannerError(fmt"Excepted true/false value but got {token}")

proc next*[T: enum](scanner: CommandScanner, kind: typedesc[T]): T =
    ## Gets the next string based enum
    scanner.skipWhitespace()
    let token = scanner.nextToken()
    for val in kind:
        if toLowerAscii($val) == token.toLowerAscii():
            return val
    raiseScannerError(fmt"{token} is not a {$type(kind)}")

proc next*[T: range](scanner: CommandScanner, kind: typedesc[T]): T =
    ## Gets the next int value in a range
    const 
        max = high T
        min = low T
    let value = scanner.next(int)
    if value in min..max:
        result = value
    else:
        raiseScannerError(fmt"value is not in range {min}..{max}")
        
proc next*(scanner: CommandScanner): string {.scanProc.}=
    ## Returns the next word that appears in the command scanner
    scanner.skipWhitespace()
    result = scanner.nextToken()
    if result.strip() == "":
        raiseScannerError("Expected a word but got nothing")

proc next*(scanner: CommandScanner): Future[GuildChannel] {.scanProc, async.} =
    ## Returns the next GuildChannel that appears. Does so by scanning to find the channel id
    ## and then looking it up here before returning
    scanner.skipWhitespace()
    var channelID: int
    let token = scanner.nextToken()
    if token.strip() == "":
            raiseScannerError(fmt"You didn't provide a channel")
    if token.scanf("<#$i>", channelID) and len($channelID) == 18:
        let chan = await scanner.api.getChannel($channelID)
        if chan[0].isSome():
            result = chan[0].get()
        else:
            raiseScannerError(fmt"{channelID} is not a valid channel")
    else:
        raiseScannerError(fmt"{token} is not a proper channel")

proc next*(scanner: CommandScanner): Future[Role] {.scanProc, async.} =
    ## Returns the next role by finding the role ID and then checking each role in the guild
    ## to see if they match and then returning it
    scanner.skipWhitespace()
    var roleID: int
    let token = scanner.nextToken()
    if token.strip() == "":
        raiseScannerError(fmt"You didn't provide a role")
    if token.scanf("<@&$i>", roleID) and len($roleID) == 18:
        result = await scanner.api.getGuildRole(scanner.message.guildID.get(), $roleID)
    else:
        raiseScannerError(fmt"{token} is not a proper role ID")

proc next*(scanner: CommandScanner): Future[User] {.scanProc, async.} =
    ## Returns the next user by finding the user ID and then looking it up
    scanner.skipWhitespace()
    var userID: int
    let token = scanner.nextToken().replace("!", "")
    if token.strip() == "":
        raiseScannerError(fmt"You didn't provide a user")
    if token.scanf("<@$i>", userID) and len($userID) == 18:
        result = await scanner.api.getUser($userID)
    else:
        raiseScannerError(fmt"{token} is not a proper userID")

proc next*[T, size: static[int]](scanner: CommandScanner, kind: typedesc[array[size, auto]]): array =
    discard

template nextSeqBody(nextTokenCode: untyped): untyped =
    ## Scans a sequence of values by continuely running the scanProc until there are no more values to parse
    ## or if it runs into a value of a different type.
    ## Be careful with this since `string` can match any type so calling this with `seq[string]` will match everything
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
        raiseScannerError("You didn't provide any items")

proc next*[T](scanner: CommandScanner): seq[T] {.scanProc.} =
    nextSeqBody(scanner.next(T))

proc next*[T](scanner: CommandScanner, kind: typedesc[Future[seq[T]]]): Future[seq[T]] {.async.} =
    nextSeqBody(await scanner.next(T))

template nextOptionalBody(nextTokenCode: untyped): untyped =
    ## Trys to scan next token and returns optional depending on if it could scan it or not
    let oldIndex = scanner.index
    try:
        result = some nextTokenCode
    except ScannerError:
        result = none T
        scanner.index = oldIndex

proc next*[T](scanner: CommandScanner): Option[T] {.scanProc.} =
    nextOptionalBody(scanner.next(T))

proc next*[T](scanner: CommandScanner, kind: typedesc[Future[Option[T]]]): Future[Option[T]] {.async.} =
    nextOptionalBody(await scanner.next(T))

