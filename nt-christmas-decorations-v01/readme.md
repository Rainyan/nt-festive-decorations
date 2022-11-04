# nt_christmas_decorations

## A Christmas Decorations plugin for Neotokyo.

Made by Rain (plugin code) and John Kaz (the present box model).

This SourceMod plugin spawns seasonal gift boxes, and also adds a sm_gift/sm_present command for spawning some more.

![Christmas plugin example](https://github.com/Rainyan/nt-festive-decorations/raw/master/example_images/xmas.jpg "Christmas plugin example")

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

#### Configuring pre-placed decorations

The decoration positions are configured in the `addons/sourcemod/configs/festive_christmas.cfg` config file.

The file takes the format:

```kv
"cfg_festive_christmas"
{
   /* Used for config compatibility. Please don't edit this value manually. */
   "version" 1

   "nt_mapname_ctg" // name of the map that this section applies for
   {
      "pos"
      {
         "rot" "1 2 3" // pre-placed decoration model's rotation in the XYZ axes
         "xyz" "4 5 6" // pre-placed decoration model's position in the XYZ coordinates
      }
      // you can define multiple "pos" entries here to define multiple positions per map
   }
   // you can define multiple maps here
}
```

#### Important things to note about placing the decorations

* Note that the `pos` nodes require the ordering of: `rot` first, and only then `xyz`! Mixing this up will end up using the `xyz` coordinates for rotation, and vice versa.
* You can have however many `pos` nodes as you like, however please note that the dynamic lighting spawned alongside with the decoration objects has an engine limit of max. 1 per each players' PVS. If you place more than 1 within the same PVS, the lights may visibly turn on/off, which tends to look bad. For more info on what a PVS is, see the [VDC wiki](https://developer.valvesoftware.com/wiki/PVS). For quickly visualizing the PVS boundaries, load the map locally, and use the console command `BindToggle P r_lockpvs` (requires `sv_cheats 1`) to bind temporarily freezing the PVS to P key.
* Since the decorations are read from file in runtime, it's not very efficient. While there isn't an upper limit set to stone, it's recommended to use less than 50 decorations per map.

The `pos` and `rot` nodes accept both integers and floating point values.

Also note that any models placed in the world origin (0, 0, 0) will be skipped -- if you need to place a model in the origin, consider slightly offsetting it in one of the axes; for example (0.001, 0, 0).

### License

* Please see the [repo main page's readme document](https://github.com/Rainyan/nt-festive-decorations) for details.
