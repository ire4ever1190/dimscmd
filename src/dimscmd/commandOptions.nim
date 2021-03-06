import dimscord
import options
import strscans
import common
import macros
import macroUtils

proc getCommandOption*(parameter: ProcParameter): ApplicationCommandOptionType =
    ## Gets the ApplicationCommandOptionType that correlates to a certain type
    
    # This checks if it is of Option[T] and extracts T if it is
    result = case parameter.kind:
        of "int":    acotInt
        of "string": acotStr
        of "bool":   acotBool
        of "user":   acotUser
        of "role":   acotRole
        of "channel", "guildchannel": acotChannel
        elif parameter.isEnum: acotStr
        else: raise newException(ValueError, parameter.kind & " is not a supported type")

proc toChoices*(options: seq[EnumOption]): seq[ApplicationCommandOptionChoice] =
    for option in options:
        result &= ApplicationCommandOptionChoice(
            name: option.name,
            value: (some option.value, none int)
        )

proc toOptions*(parameters: seq[ProcParameter]): seq[ApplicationCommandOption] =
    for parameter in parameters:
        var option = ApplicationCommandOption(
            kind: getCommandOption(parameter),
            name: parameter.name,
            description: "parameter",
            required: some (not parameter.optional),
        )
        if parameter.isEnum:
            option.choices = parameter.options.toChoices() # TODO change parameter.options to parameter.choices?
        result &= option

proc toApplicationCommand*(command: Command): ApplicationCommand =
    result = ApplicationCommand(
        name: command.name,
        description: command.description,
        options: command.parameters.toOptions()
    )

