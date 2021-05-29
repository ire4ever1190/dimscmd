import dimscord
import dimscord/restapi/requester
import std/json
import std/options
import std/sequtils
import std/asyncdispatch

##
## This file contains new/fixed functions that are not available in the latest released version of dimscord
##

when libVer != "1.2.7":
    proc `%%*`*(a: ApplicationCommand): JsonNode =
        assert a.name.len in 3..32
        assert a.description.len in 1..100
        result = %*{"name": a.name, "description": a.description}
        if a.options.len > 0: result["options"] = %(a.options.map(
            proc (x: ApplicationCommandOption): JsonNode =
                %%*x
        ))

    proc bulkOverwriteApplicationCommands*(
            api: RestApi, application_id: string; commands: seq[ApplicationCommand], guild_id = ""
    ): Future[seq[ApplicationCommand]] {.async.} =
        ## Overwrites existing commands slash command that were registered in guild or application.
        ## This means that only the commands you send in this request will be available globally or in a specific guild
        ## - `guild_id` is optional.
        let payload = %(commands.map(
            proc (a: ApplicationCommand): JsonNode =
                %%* a
        ))
        result = (await api.request(
            "PUT",
            (if guild_id != "":
                endpointGuildCommands(application_id, guild_id)
            else:
                endpointGlobalCommands(application_id)),
            $payload
        )).elems.map(newApplicationCommand)

    proc getChannel*(api: RestApi,
            channel_id: string): Future[(Option[GuildChannel], Option[DMChannel])] {.async.} =
        ## Gets channel by ID.
        ##
        ## Another thing to keep in mind is that it returns a tuple of each
        ## possible channel as an option.
        ##
        ## Example:
        ## - `channel` Is the result tuple, returned after `await`ing getChannel.
        ## - If you want to get guild channel, then do `channel[0]`
        ## - OR if you want DM channel then do `channel[1]`
        let data = (await api.request(
            "GET",
            endpointChannels(channel_id)
        ))
        if data["type"].getInt == int ctDirect:
            result = (none GuildChannel, some newDMChannel(data))
        else:
            result = (some newGuildChannel(data), none DMChannel)