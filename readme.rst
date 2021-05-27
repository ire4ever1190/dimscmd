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

    cmd.addChat("ping") do ():
        discard await discord.api.sendMessage(msg.channelID, "pong") # Message is passed to the proc as msg

    # If msg is not to your fancy then you can change it
    cmd.addChat("ping") do (m: Message):
        discard await discord.api.sendMessage(m.channelID, "pong")


Then add the handler into your message_create event using `handleMessage()` proc. It is in this proc
that you can define the prefix (or prefixes) that you want the bot to handle

.. code-block:: nim

    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
        discard await cmd.handleMessage("$$", msg) # Returns true if a command was handled
        # You can also pass in a list of prefixes
        # discard await cmd.handleMessage(@["$$", "&"], msg)

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

    cmd.addChat("kill") do (user: Some[User]):
        if user.isSome():
            discard await discord.api.sendMessage(msg.channelID, "Killing them...")
            # TODO, see if this is legal before implementing
        else:
            discard await discord.api.sendMessage(msg.channelID, "I can't kill nobody")
