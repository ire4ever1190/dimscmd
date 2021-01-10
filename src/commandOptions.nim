import dimscord
import options
import strscans
import macroUtils
import parsing

proc getCommandOption*(parameter: string): ApplicationCommandOptionType =
    ## Gets the ApplicationCommandOptionType that correlates to a certain type
    
    # This checks if it is of Option[T] and extracts T if it is
    case parameter:
        of "int":
            result = acotInt
        of "string":
            result = acotStr
        of "bool":
            result = acotBool

proc getParameterCommandOptions*(prc: NimNode): seq[ApplicationCommandOption] =
    ## Gets all the slash command options for a proc.
    ## The full proc needs to be passed instead of just seq[ProcParameter] since extra info needs to be extracted from the doc options
    for parameter in prc.getParameters():
        var commandOption = ApplicationCommandOption(
            name: parameter.name,
            description: parameter.help
        )
        # Check if the paramater is optional
        # If it is then make the command option be optional as well
        var innerType = ""
        if scanf(parameter.kind, "Option[$w]", innerType):
            commandOption.required = some true
            commandOption.kind = getCommandOption(innerType)
        else:
            commandOption.kind = getCommandOption(parameter.kind)
        result &= commandOption
