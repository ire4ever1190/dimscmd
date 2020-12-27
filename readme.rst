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


If you want to give it a different name then you can use the doc option name variable

.. code-block:: nim

    proc pingCommand() {.command.} =
		## $name: ping
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

    proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
        commandHandler("$$", msg)

The process is mostly the same for slash commands except it is in the interaction_create event and you also need to register the commands

.. code-block:: nim

	proc onReady (s: Shard, r: Ready) {.event(discord).} =
	    await discord.api.registerCommands("application ID")

	proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
    	slashCommandHandler(i)



Then just run the bot

.. code-block:: 

   you: $$ping
   bot: pong

