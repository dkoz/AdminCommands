# Palworld Admin Commands
This is an admin mod for Palworld dedicated servers. Its still in early development and coded to be cleaner than the original obfuscated mod.

Find this mod on [NexusMods](https://www.nexusmods.com/palworld/mods/2371) and [CurseForge](https://www.curseforge.com/palworld/lua-code-mods/admin-commands)!

## Commands

All commands use the `!` prefix in-game. This can be changed in the `config/config.lua`.

For setup guides and usage examples, see the [GUIDES](GUIDES.md).

### Admin Commands
| Command | Usage | Description |
|---------|-------|-------------|
| `!ban` | `!ban <player> [reason]` | Bans a player from the server and disconnects them. |
| `!unban` | `!unban <UID>` | Removes a player UID from the ban list. |
| `!kick` | `!kick <player> [reason]` | Kicks a player from the server. |
| `!slay` | `!slay <player>` | Kills a player. |
| `!fly` | `!fly enable` / `!fly disable` | Toggles fly mode for yourself. |
| `!goto` | `!goto <x> <y> <z>` or `!goto <player>` | Teleports you to coordinates or to another player. |
| `!getpos` | `!getpos` or `!getpos <player>` | Shows your current position or another player's position. |
| `!bring` | `!bring <player>` | Teleports a player to your location. |
| `!bringall` | `!bringall` | Teleports all other players to your location. |
| `!spawn` | `!spawn <PalAsset> <level> [shiny] [x,y,z]` | Spawns a Pal near you or at specific coordinates. Pass `true` for shiny. Both extras are independent. |
| `!catch` | `!catch <PalAsset> <level> [shiny] [x,y,z]` | Spawns a Pal and automatically captures it. Pass `true` for shiny. |
| `!spawnboss` | `!spawnboss <BossName>` | Spawns a configured boss from `config/bossconfig.lua`. Run with no name to list them. |
| `!give` | `!give <player> <ItemAsset>:<amount> <ItemAsset2>:<amount>` | Gives items to a target player. If no player name is given, gives to yourself. |
| `!giveme` | `!giveme <ItemAsset>:<amount> <ItemAsset2>:<amount>` | Gives items directly to yourself. |
| `!exp` | `!exp <amount>` or `!exp <player> <amount>` | Grants EXP to yourself or a target player. |
| `!freeze` | `!freeze <player>` | Freezes a player in place, preventing all movement. |
| `!unfreeze` | `!unfreeze <player>` | Unfreezes a previously frozen player. |
| `!settime` | `!settime <hour>` | Sets the in-game time (0–23). |
| `!announce` | `!announce <message>` | Broadcasts a server-wide announcement to all players. |
| `!god` | `!god on` / `!god off` | Toggles invincibility for yourself. |
| `!destroybase` | `!destroybase <x,y,z>` | Destroys a base camp near the given coordinates. |
| `!destroynearestbase` | `!destroynearestbase` | Destroys the nearest base camp to your location. |
| `!admingun` | `!admingun on` / `!admingun off` | Toggles Admin Gun mode. Shoot a palbox to destroy its base camp. |

### Player Commands
| Command | Usage | Description |
|---------|-------|-------------|
| `!help` | `!help` | Shows list of available commands. |
| `!unstuck` | `!unstuck` | Teleports yourself to a safe point. |
| `!time` | `!time` | Displays the current in-game time. | 

## Licensing
If you wish to use the code in your projects just provide credit, that's all I ask.

## Pull Requests
This project is open to pull requests and code contributions.

### Contributing AI Code
I do not mind you utilizing AI to implement code to this project. Just make sure it respects the code structure, code implementation and that the code is functional and tested.

## Credits
> People who have helped me with various aspects of this project in the past.
- Okaetsu
- Sharkey
- Mathayus