import dimscord
import options
import strscans
import common
import macros
import macroUtils
import utils
{.experimental: "caseStmtMacros".}

proc getCommandOption*(parameter: ProcParameter): ApplicationCommandOptionType =
    ## Gets the ApplicationCommandOptionType that correlates to a certain type
    if parameter.isEnum: acotStr
    else:
        matchIdent(parameter.kind):
            "int":    acotInt
            "string": acotStr
            "bool":   acotBool
            "User":   acotUser
            "Role":   acotRole
            ("Channel", "GuildChannel"): acotChannel
            else: raise newException(ValueError, parameter.kind & " is not a supported type")

proc toChoices*(options: seq[EnumOption]): seq[ApplicationCommandOptionChoice] =
    for option in options:
        result &= ApplicationCommandOptionChoice(
            name: option.name,
            value: (some option.value, none int)
        )

proc toOptions*(parameters: seq[ProcParameter]): seq[ApplicationCommandOption] =
    for parameter in parameters:
        let description = if parameter.help == "": # Just use a default instead of breaking
                "parameter"
            else:
                parameter.help

        var option = ApplicationCommandOption(
            kind: getCommandOption(parameter),
            name: parameter.name,
            description: description,
            required: some (not parameter.optional)
        )
        if parameter.isEnum:
            option.choices = parameter.options.toChoices() # TODO change parameter.options to parameter.choices?
        result &= option

proc toApplicationCommand*(command: Command): ApplicationCommand {.inline.} =
    result = ApplicationCommand(
        name: command.name.leafName(),
        description: command.description,
        options: command.parameters.toOptions(),
        defaultPermission: true
    )

proc toOption(group: CommandGroup): ApplicationCommandOption =
    ## Recursively goes through a command group to generate the
    ## command options for each sub group and sub command
    if group.isLeaf: # Base case, create the command
        let cmd = group.command
        result = ApplicationCommandOption(
            kind: acotSubCommand,
            name: group.name,
            description: cmd.description,
            options: cmd.parameters.toOptions(),
        )
    else: # Not a command so the group needs to be created
        result = ApplicationCommandOption(
            kind: acotSubCommandGroup,
            name: group.name,
            description: group.name & " group"
        )
        for child in group.children:
            result.options &= child.toOption()

proc toApplicationCommand*(group: CommandGroup): ApplicationCommand =
    ## Makes an ApplicationCommand from a CommandGroup
    # Normal commands and command groups use different objects in the discord api
    # This first checks if the group is a leaf node e.g. it is a single level command like /ping
    # If it has children (like with the case /calc add) then those commands need to be converted to an
    # `ApplicationCommandOption` instead of an `ApplcationCommand`, that part is handled in `toOption`
    if group.isLeaf:
        # If it is a normal command then just do straight conversion
        result = group.command.toApplicationCommand()
    else:
        # If it is a command group then loop through it's children
        # and create ApplicationCommandOptions for them
        result = ApplicationCommand(
            name: group.name,
            kind: atSlash,
            description: group.name & " group", 
            defaultPermission: true)
        for child in group.children:
            result.options &= child.toOption()

