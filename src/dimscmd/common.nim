import dimscord/objects
import std/asyncdispatch
import std/tables

type
    ProcParameter* = object
        name*: string
        kind*: string
        optional*: bool
        sequence*: bool
        help*: string

    CommandType* = enum
        ## A chat command is a command that is sent to the bot over chat
        ## A slash command is a command that is sent using the slash commands functionality in discord
        ctChatCommand
        ctSlashCommand

    ChatCommandProc* = proc (s: Shard, m: Message): Future[void] # The message variable is exposed has `msg`
    SlashCommandProc* = proc (s: Shard, i: Interaction): Future[void] # The Interaction variable is exposed has `i`

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
        # TODO move from a table to a tree like structure. It will allow the user to declare command groups if they are in a tree
        chatCommands*: Table[string, Command]
        slashCommands*: Table[string, Command]