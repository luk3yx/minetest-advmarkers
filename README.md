# advmarkers (non-CSM)

A marker/waypoint mod for Minetest. Requires Minetest 5.0.0+, if you use Minetest 0.4 please try [this older version from June 2020](https://git.minetest.land/luk3yx/advmarkers/commit/25d7079069a53f2cece76ee2050bcdf690b4ea30).

Unlike the [CSM], this mod is standalone, and conflicts with the marker mod.

## How to use

This mod introduces the following chatcommands:

 - `/wp`, `/mrkr`: Opens a formspec allowing you to display or delete waypoints. If you give this command a parameter (`h`/`here`, `t`/`there` or co-ordinates), it will set your HUD position to those co-ordinates.
 - `/add_wp`, `/add_mrkr`: Adds markers. You can use `.add_mrkr x,y,z Marker name` to add markers. Adding a marker with (exactly) the same name as another will overwrite the original marker.
 - `/clrwp`, `/clrmrkr`: Hides the currently displayed waypoint.
 - `/mrkr_export`: Exports your markers to an advmarkers string. Remember to not modify the text before copying it. You can use `/mrkr_export old` if you want an export string compatible with older versions of the advmarkers CSM (it should start with `M` instead of `J`). This old format does **not** work with this mod, so only use it if you know what you are doing!
 - `/mrkr_import`: Imports your markers from an advmarkers string (`/mrkr_import <advmarkers string>`). Any markers with the same name will not be overwritten, and if they do not have the same co-ordinates, `_` will be appended to the imported one.
 - `/mrkrthere`: Alias for `/mrkr there`.

If you die, a waypoint is automatically added at your death position, and will
update the "there" position.

## "Here" and "there" positions

Both /wp and /add_wp accept "here"/"h" and "there"/"t" in place of
co-ordinates. Using "here" will set the waypoint to your current position, and
"there" will set it to the most recent co-ordinates that appear in chat (or
your last death position).

## SSCSM support

With my [SSCSM] mod installed, advmarkers will register a server-sent CSM to
reduce visible lag in the markers GUI.

[CSM]:    https://git.minetest.land/luk3yx/advmarkers-csm
[SSCSM]:  https://content.minetest.net/packages/luk3yx/sscsm
