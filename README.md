# advmarkers

A not very advanced marker/waypoint mod for Minetest.

Unlike the [CSM], this mod is standalone, and conflicts with the
[marker mod](https://github.com/Elkien3/citysim_game/tree/master/mods/marker).

## How to use

This mod introduces the following chatcommands:

 - `/wp`, `/mrkr`: Opens a GUI allowing you to display or delete waypoints. If you give this command a parameter (`h`/`here`, `t`/`there` or co-ordinates), it will set your HUD position to those co-ordinates.
 - `/add_wp`, `/add_mrkr`: Adds markers. You can use `.add_mrkr x,y,z Marker name` to add markers. Adding a marker with (exactly) the same name as another will overwrite the original marker.
 - `/clrwp`, `/clrmrkr`: Hides the currently displayed waypoint.
 - `/mrkr_export`: Exports your markers to an advmarkers string. Remember to not modify the text before copying it.
 - `/mrkr_import`: Imports your markers from an advmarkers string (`/mrkr_import <advmarkers string>`). Any markers with the same name will not be overwritten, and if they do not have the same co-ordinates, `_` will be appended to the imported one.
 - `/mrkrthere`: Alias for `/mrkr there`.

If you die, a waypoint is automatically added at your death position, and will
update the "there" position.

## "Here" and "there" positions

Both /wp and /add_wp accept "here"/"h" and "there"/"t" in place of
co-ordinates. Using "here" will set the waypoint to your current position, and
"there" will set it to the most recent co-ordinates that appear in chat (or
your last death position).

[CSM]:    https://gitlab.com/luk3yx/minetest-advmarkers-csm
