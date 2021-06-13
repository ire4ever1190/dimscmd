import dimscord/objects
import std/asyncdispatch
import std/tables
import segfaults

type
    ProcParameterSetting* = enum
        Optional
        Future
        Sequence
        Array # Implement
        Enum

    ProcParameter* = object
        name*: string
        kind*: string         # The name of the object but in lower case and without _
        originalKind*: string # The original object name
        optional*: bool
        future*: bool
        sequence*: bool
        isEnum*: bool
        options*: seq[EnumOption]     # only when an enum
        length: int          # Only when an array
        help*: string

    CommandType* = enum
        ## A chat command is a command that is sent to the bot over chat
        ## A slash command is a command that is sent using the slash commands functionality in discord
        ctChatCommand
        ctSlashCommand

    EnumOption* = object
        name*: string
        value*: string

    ChatCommandProc* = proc (s: Shard, m: Message): Future[void] # The message variable is exposed as `msg`
    SlashCommandProc* = proc (s: Shard, i: Interaction): Future[void] # The Interaction variable is exposed as `i`

    Command* = object
        name*: string
        description*: string
        parameters*: seq[ProcParameter]
        guildID*: string
        case kind*: CommandType
            of ctSlashCommand:
                slashHandler*: SlashCommandProc
            of ctChatCommand:
                chatHandler*: ChatCommandProc
                discard

    CommandHandler* = ref object
        discord*: DiscordClient
        applicationID*: string # Needed for slash commands
        msgVariable*: string
        chatCommands*: Table[string, Command]
        slashCommands*: Table[string, Command]
