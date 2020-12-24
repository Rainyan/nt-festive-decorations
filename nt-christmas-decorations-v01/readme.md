# nt_christmas_decorations

## A Christmas Decorations plugin for Neotokyo.

Made by Rain (plugin code) and John Kaz (the present box model).

This SourceMod plugin spawns seasonal gift boxes, and also adds a sm_gift/sm_present command for spawning some more.

### Installation

* Compile the source code in "addons". It requires SourceMod 1.7 or newer, and the Neotokyo SM include:
    * https://github.com/softashell/sourcemod-nt-include

* Add all of the "materials" and "models" file paths to your server. If you're using fastdl, be sure to include the files in those folders there, as well.
    * They can be .bz2'd on fastdl, but only as individual files (no multiple assets inside the same archive file).

### Usage

#### Player commands
* *sm_gift* (or *!gift* in chat) — Spawn a gift box in the map.
* *sm_present* (or !present in chat) — Alias of sm_gift.

#### Server cvars
* *sm_festive_decorations_christmas_version* — Plugin version.
* *sm_festive_decorations_christmas_lightswitch_speed* — This controls how fast the colored lights spawned by this plugin should change color. Larger value means a slower change of colors. Default: 5. Value range: 1-100.
* *sm_festive_decorations_christmas_limit* — How many !gifts per round can each player spawn. Limited for performance/fps reasons. Default: 20. Value range: 0 - 1000.
* *sm_festive_decorations_christmas_specs_may_spawn* — Whether spectators are allowed to !gift. 0: spectators can never spawn !gifts, 1: spectators can always spawn !gifts visible to all players, 2: spectator !gifts are only visible to other spectating players. Default: 2. Value range: 0-2.

### License

* Please see the [repo main page's readme document](https://github.com/Rainyan/nt-festive-decorations) for details.

## Example image

![Christmas plugin example](https://github.com/Rainyan/nt-festive-decorations/raw/master/example_images/xmas.jpg "Christmas plugin example")
