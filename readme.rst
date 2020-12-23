***********************
Dimscord Command Handler
***********************

Setup
=====

Create your commands using the `command` pragma

.. code-block:: nim
    proc ping() {.command.} =
        ## I pong
        await discord.api.sendMessage(msg.channelId, "pong")


If you want to give it a different name then you can use the `ncommand` pragma

.. code-block:: nim
    proc pingCommand() {.ncommand(name = "ping").} =
        ## I pong
        await discord.api.sendMessage(msg.channelId, "pong")


If you want to receive parameters along with the command then just add them to the proc

.. code-block:: nim
    proc echo(word: string) {.command.} =
        ## I repeat the word that you give
        await discord.api.sendMessage(msg.channelId, word)


Then add the handler into your message_create event using `commandHandler()`
the first parameter to commandHandler is the prefix that you want to use and the second is the msg variable

.. code-block:: nim
    discord.events.message_create = proc (s: Shard, msg: Message) {.async.} =
        commandHandler("$$", msg)


Then just run the bot

.. code-block:: 
   you: $$ping
   bot: pong

