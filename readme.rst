***********************
Dimscord Command Handler
***********************

.. image:: https://github.com/ire4ever1190/dimscmd/workflows/Tests/badge.svg
    :alt: Test status
    
This is built on top of the amazing `dimscord library <https://github.com/krisppurg/dimscord>`_ so if you have any questions about using dimscord or dimscmd then join the `dimscord discord <https://discord.com/invite/dimscord>`_ (please send questions about dimscmd in the #dimscmd channel)

`Docs available here <https://tempdocs.netlify.app/dimscmd/stable>`_

Install
====

.. code-block::

    nimble install dimscmd

Setup
=====

First create the handler object

.. code-block:: nim

    import dimscord
    import dimscmd
    let discord = newDiscordClient(token)
    var cmd = discord.newHandler() # Must be var

Then add the handler into your message_create event using `handleMessage()` proc. It is in this proc
that you can define the prefix (or prefixes) that you want the bot to handle

.. code-block:: nim

    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
        discard await cmd.handleMessage("$$", s, msg) # Returns true if a command was handled
        # You can also pass in a list of prefixes
        # discard await cmd.handleMessage(@["$$", "&"], s, msg)

Use
====

Commands are created using Nim's do notation

.. code-block:: nim

    cmd.addChat("ping") do ():
        discard await discord.api.sendMessage(msg.channelID, "pong") # Message is passed to the proc as msg

    # If msg is not to your fancy then you can change it
    cmd.addChat("ping") do (m: Message):
        discard await discord.api.sendMessage(m.channelID, "pong")

But you are probably wondering "can I add parameters to my commands?" and the answer is yes and it is very easy.
Just add parameters to the signature and you're off

.. code-block:: nim

    cmd.addChat("echo") do (word: string):
        discard await discord.api.sendMessage(m.channelID, word)

    # You can add as many types as you want
    cmd.addChat("repeat") do (word: string, times: int):
        for i in 0..<times:
            discard await discord.api.sendMessage(m.channelID, word)


Current supported types are (don't think you want any other types)
    - string
    - bool
    - int
    - enums
    - discord user
    - discard channel
    - discord role

seq[T] and Option[T] for those types are also supported

.. code-block:: nim

    cmd.addChat("sum") do (nums: seq[int]):
        var sum = 0
        for num in nums:
            sum += num
        discard await discord.api.sendMessage(m.channelID, $sum)

.. code-block:: nim

    cmd.addChat("kill") do (user: Option[User]):
        if user.isSome():
            discard await discord.api.sendMessage(msg.channelID, "Killing them...")
            # TODO, see if this is legal before implementing
        else:
            discard await discord.api.sendMessage(msg.channelID, "I can't kill nobody")

Dimscmd does do other stuff like generate a help message automatically when the user sends the message "help" after
the prefix. This can be overrided by defining a help command yourself

.. code-block:: nim

    cmd.addChat("help") do (commandName: Option[string]): # parameters can be whatever you want
        if commandName.isSome():
            # Send help message for that command
        else:
            # Say something helpful


Slash commands
====

Slash commands are also supported with this library and are declared in a similar fashion. There are some things to
be mindful of though when using slash commands such as
 - names cannot contain capital letters
 - This library currently doesn't provide any help with creating interaction responses

First add the handler into the interaction create event like with messages and also
add the command register into the on ready event

.. code-block:: nim

    proc onReady (s: Shard, r: Ready) {.event(discord).} =
        await cmd.registerCommands()

    proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
        discard await cmd.handleInteraction(s, i)

Then add your slash commands

.. code-block:: nim

    cmd.addSlash("add") do (a: int, b: int):
        ## Adds two numbers
        let response = InteractionResponse(
            kind: irtChannelMessageWithSource,
            data: some InteractionApplicationCommandCallbackData(
                content: fmt"{a} + {b} = {a + b}"
            )
        )
        await discord.api.createInteractionResponse(i.id, i.token, response)

Slash commands support the types supported (including enums) with the exception of seq[T]


During testing it is recommend that you set a specific guild so that slash commands
will be registered instantly (instead of waiting an hour for them to be register globally)

.. code-block:: nim

    cmd.addSlash("add", guildID = "123456789") do (a: int, b: int):
        ## Adds to numbers
        ...

    # I recommend setting up something like this
    when defined(debug):
        const defaultGuildID = "3456789"
    else:
        const defaultGuildID = "" # Global

    cmd.addSlash("add", guildID = defaultGuildID) do (a: int, b: int):
        ## Adds to numbers
        ...
