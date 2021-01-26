***********************
Dimscord Command Handler
***********************

Setup
=====

First create the handler object

.. code-block:: nim

    import dimscord
    import dimscmd
    let discord = newDiscordClient(token)
    var cmd = discord.newHandler() # Must be var


From there you create commands using nims do notation

.. code-block:: nim

    cmd.addChat("echo") do (word: string) = # Supported types currently are int and string
        discord.api.sendMessage(msg.channelId, word) # Message is passed to the proc has msg



Then add the handler into your message_create event using `commandHandler()`
the first parameter to commandHandler is the prefix that you want to use and the second is the msg variable

.. code-block:: nim

    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
        discard await cmd.handleMessage("$$", msg) # Returns true if a command was handled
        # You can also pass in a list of prefixes
        discard await cmd.handleMessage(["$$", "&"], msg)

