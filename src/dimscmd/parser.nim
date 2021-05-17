import std/parseutils
import std/strformat
import std/strutils
import dimscord

type
    CommandParser* = ref object
        api: RestApi
        message: Message
        index*: int

    ParserError* = object of ValueError

proc input(parser: CommandParser): string =
    result = parser.message.content

proc newParser*(input: string, api: RestApi = nil): CommandParser =
    result = CommandParser(
        api: api,
        message: Message(content: input),
        index: 0
    )

proc printCurrentSpot(parser: CommandParser) =
    echo parser.input
    echo " ".repeat(parser.index) & "^"

proc newParser*(api: RestApi, msg: Message): CommandParser =
    result = CommandParser(
        api: api,
        message: msg,
        index: 0
    )

proc hasMore(parser: CommandParser): bool =
    result = parser.index < parser.input.len()

proc nextToken(parser: CommandParser): string =
    ## Gets the next token
    parser.index += parser.input.parseUntil(result, ' ', parser.index)

proc skipWhitespace(parser: CommandParser) =
    ## Skips past whitespace and sets the current index to the character that follows
    ## Is ran before every other parsing function so it should not be called manually
    parser.index += parser.input.skipWhitespace(parser.index)

proc nextInt*(parser: CommandParser): int =
    ## Parses the next available integer
    parser.skipWhitespace()
    let processedChars = parser.input.parseInt(result, parser.index)
    if processedChars == 0:
        var token: string
        discard parser.input.parseUntil(token, ' ')
        raise newException(ParserError, fmt"Expected integer but got {token}")
    else:
        parser.index += processedChars

proc nextBool*(parser: CommandParser): bool =
    ## Parses the next boolean value.
    ## Possible values for true are
    ##      - true
    ##      - yes
    ##      - 1
    ## possible values for false are
    ##      - false
    ##      - yes
    ##      - 0
    parser.skipWhitespace()
    let token = parser.nextToken()
    result = case token.toLowerAscii():
        of "true", "1", "yes":
            true
        of "false", "0", "no":
            false
        else:
            raise newException(ParserError, fmt"Excepted boolean but got {token}")

proc nextString*(parser: CommandParser): string =
    parser.skipWhitespace()
    result = parser.nextToken()
    if result.len() == 0:
        raise newException(ParserError, "Expected a token but got nothing")

proc nextChannel*(parser: CommandParser): Future[GuildChannel] {.async.} =
    parser.skipWhitespace()
    var channelID: int
    let token = parser.nextToken()
    if token.scanf("<#$i>", channelID):
        let chan = await parser.api.getChannel($channelID)
        if chan[0].isSome():
            result = chan[0].get()
        else:
            raise newException(ParserError, fmt"{channelID} is not a valid channel")
    else:
        raise newException(ParserError, fmt"{token} does not start with a proper channel ID")

template nextSeqBody(nextTokenCode: untyped): untyped =
    ## Parses a sequence of values by continuely running the parseProc until there are no more values to parse
    ## or it runs into a value of a different type
    while parser.hasMore():
        var next: T
        try:
            next = nextTokenCode
        except ParserError:
            break
        result &= next
    if result.len() == 0:
        raise newException(ParserError, "No values were able to be parsed")

proc nextSeq*[T](parser: CommandParser, parseProc: proc (parser: CommandParser): T): seq[T] =
    nextSeqBody(parser.parseProc())

proc nextSeq*[T](parser: CommandParser, parseProc: proc (parser: CommandParser): Future[T]): Future[seq[T]] {.async.} =
    ## Parses a sequence of values by continuely running the parseProc until there are no more values to parse
    ## or it runs into a value of a different type
    nextSeqBody(await parser.parseProc())
