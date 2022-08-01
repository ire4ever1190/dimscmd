import dimscord/objects
import std/[
    asyncdispatch,
    tables,
    strformat,
    strutils,
    sets
]
import utils

type
    ProcParameterSetting* = enum #
        Optional
        Future
        Sequence
        Array # TODO, Implement
        Enum

    ProcParameter* = object
        name*: string
        kind*: string
        # originalKind*: string # The original object name
        # Convert these to a bit set maybe?
        optional*: bool
        future*: bool
        sequence*: bool
        isEnum*: bool
        array*: bool
        options*: seq[EnumOption]     # only when an enum
        # Only when an array
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
        # The full name is stored so that the alias names can be found
        names*: seq[string] ## The name includes the command groups
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

func `$`(command: Command): string =
    result = "Names: " & command.names.join(", ") & "\n"
    result &= "Description: " & command.description

# Getters for Command
func name*(command: Command): string = command.names[0]
func aliases*(command: Command): seq[string] = command.names[1..^1]

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
    CommandGroup(
        name: cmd.name.split(" ")[^1],
        isLeaf: true,
        command: cmd
    )

proc print*(group: CommandGroup, depth = 1) =
  ## Used for debugging, prints out the tree structure of the group.
  ## If the node is a handler then it is suffixed with -
  for child in group.children:
    echo child.name.indent(depth) & (if child.isLeaf: " - " else: "")
    if not child.isLeaf:
      child.print(depth + 1)

func flatten*(group: CommandGroup, name = ""): seq[Command] =
    ## Flattens a group into a sequence of tuples
    ## containing the path to the command and the command
    # Keep a set of visited command names
    # since every name needs to be unique, we will only be checking the first name (not the alises)
    var visited = initHashSet[string]()
    var stack = @[group]
    while stack.len > 0:
        let currentGroup = stack.pop()
        if currentGroup.isLeaf:
            let command = currentGroup.command
            if command.name notin visited:
                visited.incl command.name
                result &= command
        else:
            # Add all the children to the fountier to be searched
            for child in currentGroup.children:
                stack &= child

proc chatCommandsAll*(cmd: CommandHandler): seq[Command] = cmd.chatCommands.flatten()
proc slashCommandsAll*(cmd: CommandHandler): seq[Command] = cmd.slashCommands.flatten()

template traverseTree(current: CommandGroup, key: openarray[string],
                      after: untyped): untyped {.dirty.} =
    ## Traverses the command tree
    ## `after` Runs after it has checked all the children
    for part in key:
        var found = false
        for group in current.children:
            if part == group.name:
                current = group
                found = true
                break
        if current.isLeaf:
            break
        after

func map*(root: CommandGroup, key: openarray[string], cmd: Command) =
    ## Maps the command to the tree using key
    var currentNode = root
    var index = 0
    currentNode.traverseTree(key):
        if not found:
            let newChild = if index == key.len - 1: # At the end of the command
                CommandGroup(
                    isLeaf: true,
                    name: key[^1],
                    command: cmd
                )
            else:
                newGroup(part, "")
            currentNode.children &= newChild
            currentNode = newChild
        inc index

func map*(root: CommandGroup, cmd: Command) =
    ## Maps the command to the tree. Gets the key from the command name
    let key = cmd.name.getWords()
    root.map(key, cmd)

func getGuildID*(root: CommandGroup): string =
    ## Returns the first guildID for the first command
    # TODO, check if discords api allows different guild ids
    result = root.flatten()[0].guildID

func getGroup*(root: CommandGroup, key: openarray[string]): CommandGroup =
    ## Like `get` except it returns the group that the command belongs to
    var currentNode = root
    currentNode.traverseTree(key):
        if not found:
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
    # And return false if proved otherwise
    if not found:
      return false
      
func mapAltPath*(root: CommandGroup, a, b: openarray[string]) =
    ## Makes b also point to a
    ## Checks for ambiguity before adding
    doAssert root.has(a), "The parent command must exist"
    if not root.has(a):
        raise newException(ValueError, fmt"{a} does not exist, check it is defined before calling addChatAlias")
    if root.has(b):
        raise newException(ValueError, fmt"Cannot use the same name as a command that already exists for the alias {b}")

    var currentNode = root
    # Map b to the same object as a
    root.map(b, root.get(a))
