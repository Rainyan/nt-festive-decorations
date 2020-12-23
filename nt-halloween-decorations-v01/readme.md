# nt_halloween_decorations

## A Halloween Decorations plugin for Neotokyo.

Made by Rain (plugin code) and John Kaz (the pumpkin model).

This SourceMod plugin spawns spooky pumpkins, and also adds a !pumpkin chat command for spawning some more.

### Installation

* Compile the source code in "addons". It requires SourceMod 1.7 or newer, and the Neotokyo SM include:
    * https://github.com/softashell/sourcemod-nt-include

* Add the "materials" and "models" paths to your server. If you're using fastdl, be sure to include the files in those folders there, as well.
    * They can be .bz2'd on fastdl, but only as individual files (no folder structure inside the archive).

### Usage

#### Player commands
* *sm_pumpkin* (or *!pumpkin* in chat) — Spawns a pumpkin in the map where the player is aiming.

#### Server cvars
* *sm_festive_decorations_halloween_version* — Plugin version.
* *sm_festive_decorations_halloween_limit* — How many !pumpkins per round can each player spawn. Limited for performance/fps reasons. Default: 20. Value range: 0 - 1000.
* *sm_festive_decorations_halloween_specs_may_spawn* — Whether spectators are allowed to !pumpkin. Spectator !pumpkins are always invisible to living players for gameplay reasons.

### License

* Please see the [repo main page's readme document](https://github.com/Rainyan/nt-festive-decorations) for details.

## Example image

![Halloween plugin example](https://github.com/Rainyan/nt-festive-decorations/raw/master/example_images/halloween.jpg "Halloween plugin example")
