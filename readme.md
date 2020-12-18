## Dimscord Command Handler

#### Setup

Create your commands

```nim
    proc ping() {.command.} =
        ## I pong
        await discord.api.sendMessage(msg.channelId, "pong")
```

Then add the handler into your message_create event

```nim
    discord.events.message_create = proc (s: Shard, msg: Message) {.async.} =
        commandHandler("$$", msg)
```

Then just run the bot

```
   you: $$ping
   bot: pong
```
