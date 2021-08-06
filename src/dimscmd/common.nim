import dimscord/objects
import std/[
    asyncdispatch,
    tables,
    strformat,
    strutils
]
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
        kind*: string
        # originalKind*: string # The original object name
        optional*: bool
        future*: bool
        sequence*: bool
        isEnum*: bool
        options*: seq[EnumOption]     # only when an enum
        length: int                   # Only when an array
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
    HandlerProcs* = ChatCommandProc | SlashCommandProc

    CommandGroup* = ref object
        name*: string
        case isleaf*: bool
            of true:
                command*: Command
            of false:
                children*: seq[CommandGroup]
                description*: string

    Command* = ref object
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
        chatCommands*: CommandGroup
        slashCommands*: CommandGroup

func newGroup*(name: string, description: string, children: seq[CommandGroup] = @[]): CommandGroup =
    ## Creates a group object which is used by the command
    ## handler for routing groups
    assert ' ' notin name, "Name cannot contain spaces"
    CommandGroup(
        name: name,
        isLeaf: false,
        description: description,
        children: children
    )

func newGroup*(cmd: Command): CommandGroup =
    ## Creates a leaf node from a command
    # assert ' ' notin cmd.name, "Name cannot contain spaces"
    CommandGroup(
        name: cmd.name.split(" ")[^1],
        isLeaf: true,
        command: cmd
    )

type FlattenedCommands = seq[tuple[groupName: string, cmd: Command]]

proc print*(group: CommandGroup, depth = 1) =
    for child in group.children:
        echo child.name.indent(depth)
        if not child.isLeaf:
            child.print(depth + 1)

func flatten*(group: CommandGroup, name = ""): FlattenedCommands =
    ## Flattens a group into a sequence of tuples
    ## containing the path to the command and the command
    if group.isLeaf:
        return @[(group.name, group.command)]
    for child in group.children:
        if child.isLeaf:
            result &= (groupName: strip(name & " " & child.name), cmd: child.command)
        else:
            result &= flatten(child, name & " " & child.name)

proc chatCommandsAll*(cmd: CommandHandler): FlattenedCommands = cmd.chatCommands.flatten()
proc slashCommandsAll*(cmd: CommandHandler): FlattenedCommands = cmd.slashCommands.flatten()

template traverseTree(current: CommandGroup, key: openarray[string], notFound: untyped): untyped {.dirty.} =
    ## Traverses the command tree
    ## Runs code if a key is not found at end level
    for part in key:
        var found = false
        for group in current.children:
            if group.name == part:
                current = group
                found = true
                break

        if not found:
            notFound

func map*(root: CommandGroup, key: openarray[string], cmd: sink Command) =
    var currentNode = root
    currentNode.traverseTree(key):
        # Add a new child if not can't be found
        var newChild = newGroup(part, "")
        currentNode.children &= newChild
        currentNode = newChild
    if currentNode.isLeaf:
        raise newException(KeyError, "Cannot have a group name be the same as another command")
    # Add the command to the end as a leaf node
    currentNode.children &= cmd.newGroup()

func getGuildID*(root: CommandGroup): string =
    ## Returns the first guildID for the first command
    result = root.flatten()[0].cmd.guildID



func getGroup*(root: CommandGroup, key: openarray[string]): CommandGroup =
    ## Like `get` except it returns the group that the command belongs to
    var currentNode = root
    currentNode.traverseTree(key):
        raise newException(KeyError, fmt"Could not find {part} in {key}")
    result = currentNode


func get*(root: CommandGroup, key: openarray[string]): Command =
    ## Returns the command that belongs to `key`
    let group = root.getGroup(key)
    if group.isLeaf:
        result = group.command
    else:
        raise newException(KeyError, fmt"{key} does not match a leaf node")

func has*(root: CommandGroup, key: openarray[string]): bool =
    ## Returns true if the key points to a command or a command group
    var currentNode = root
    result = true # We assume by default that the key exists
    currentNode.traverseTree(key):
        # And set it to false if proved otherwise
        result = false
        break
