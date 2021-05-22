import dimscord

type
    InteractionCommand = object
        name: string
        description: string


proc `[]`(data: Interaction): ApplicationCommandInteractionDataOption =
    data.options

proc newInteractionCommand(name): InteractionCommand = discard