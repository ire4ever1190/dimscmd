import common

## This file implements the sub commands code and dsl

# type
#     CompGroup = object
#         group: CommandGroup
#         handlers: seq[NimNode] # Will be transformed into leaf nodes later
#
# proc createGroup*(name, description: string): CompGroup =
#     result.group = newGroup(name, description)
#
# macro addSlash*(group: CompGroup, handler: varargs[untyped]) =
#     group.handlers &= handler