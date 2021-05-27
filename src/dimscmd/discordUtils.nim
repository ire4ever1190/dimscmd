import std/asyncdispatch
import dimscord

##
## This module contains helper functions that are used internally
##

proc getGuildRole*(api: RestApi, gid, id: string): Future[Role] {.async.} =
    ## Gets the role from a guild with specific id
    let roles = await api.getGuildRoles(gid)
    for role in roles:
        if role.id == id:
            return role