import std/parseutils
import std/strformat
import std/strutils
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

proc printCurrentSpot(scanner: CommandScanner) =
    echo scanner.input
    echo " ".repeat(scanner.index) & "^"

proc newScanner*(api: RestApi, msg: Message): CommandScanner =
    result = CommandScanner(
        api: api,
        message: msg,
        index: 0
    )

proc hasMore(scanner: CommandScanner): bool =
    result = scanner.index < scanner.input.len()

proc nextToken(scanner: CommandScanner): string =
    ## Gets the next token
    scanner.index += scanner.input.parseUntil(result, ' ', scanner.index)

proc skipWhitespace(scanner: CommandScanner) =
    ## Skips past whitespace and sets the current index to the character that follows
    ## Is ran before every other parsing function so it should not be called manually
    scanner.index += scanner.input.skipWhitespace(scanner.index)

proc nextInt*(scanner: CommandScanner): int =
    ## Parses the next available integer
    scanner.skipWhitespace()
    let processedChars = scanner.input.parseInt(result, scanner.index)
    if processedChars == 0:
        var token: string
        discard scanner.input.parseUntil(token, ' ')
        raise newException(ScannerError, fmt"Expected integer but got {token}")
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
            raise newException(ScannerError, fmt"Excepted boolean but got {token}")

proc nextString*(scanner: CommandScanner): string =
    scanner.skipWhitespace()
    result = scanner.nextToken()
    if result.len() == 0:
        raise newException(ScannerError, "Expected a token but got nothing")

proc nextChannel*(scanner: CommandScanner): Future[GuildChannel] {.async.} =
    scanner.skipWhitespace()
    var channelID: int
    let token = scanner.nextToken()
    if token.scanf("<#$i>", channelID):
        let chan = await scanner.api.getChannel($channelID)
        if chan[0].isSome():
            result = chan[0].get()
        else:
            raise newException(ScannerError, fmt"{channelID} is not a valid channel")
    else:
        raise newException(ScannerError, fmt"{token} does not start with a proper channel ID")

template nextSeqBody(nextTokenCode: untyped): untyped =
    ## Scans a sequence of values by continuely running the scanProc until there are no more values to parse
    ## or if it runs into a value of a different type
    while scanner.hasMore():
        var next: T
        try:
            next = nextTokenCode
        except ScannerError:
            break
        result &= next
    if result.len() == 0:
        raise newException(ScannerError, "No values were able to be parsed")

proc nextSeq*[T](scanner: CommandScanner, scanProc: proc (scanner: CommandScanner): T): seq[T] =
    nextSeqBody(scanner.scanProc())

proc nextSeq*[T](scanner: CommandScanner, scanProc: proc (scanner: CommandScanner): Future[T]): Future[seq[T]] {.async.} =
    nextSeqBody(await scanner.scanProc())
