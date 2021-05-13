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


From there you create commands using Nim's do notation

.. code-block:: nim

    cmd.addChat("echo") do (word: string) =
        discard await discord.api.sendMessage(msg.channelID, word) # Message is passed to the proc as msg

    # If msg is not to your fancy then you can change it
    cmd.addChat("echo") do (word: string, m: Message) =
        discard await discord.api.sendMessage(m.channelID, word)


Then add the handler into your message_create event using `commandHandler()`
the first parameter to commandHandler is the prefix that you want to use and the second is the msg variable

.. code-block:: nim

    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
        discard await cmd.handleMessage("$$", msg) # Returns true if a command was handled
        # You can also pass in a list of prefixes
        discard await cmd.handleMessage(@["$$", "&"], msg)

More advanced types like User, Role, and Channel can also be parsed using the same syntax

.. code-block:: nim
    cmd.addChat("kill") do (user: User) =
        discard await discord.api.sendMessage(msg.channelID, "Killing them...")
        # TODO, see if this is legal before implementing