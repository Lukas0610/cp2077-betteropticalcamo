Better Optical Camo
=====
Version 2.0.0

[Better Optical Camo at Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/4159)

[Better Optical Camo source at GitHub](https://github.com/Lukas0610/cp2077-betteropticalcamo)

Improves the optical camo by allowing the player to toggle it on/off, change several settings like
charge-decay/regen (how fast the energy depletes and regenerates), allow the camo to be enabled indefinitely
and to recharge immediately when turning off.

Since 2.0, a combat-cloak has been added, actually making the player invisible to entities and removing
enemies from combat after a (configurable) delay.

The settings can be found in the "Mods" menu entry under "Better Optical Camo"

#### Compatible with (Require an compatibility-addon to be installed)
* "Custom Quickslots"

-----

#### Dependencies
* Cyber Engine Tweaks
* Native Settings UI
* redscript (Optional; See notes for installation and "Custom Quickslots")

-----

#### Installation
* Extract the downloaded ZIP and copy the contents of the "Core Mod" directory into the game directory
* (Optional) If you use "Custom Quickslots", also copy the contents of "Compatibility Addons\Custom Quickslots" into the game directory

-----

#### Translating
Since 2.0.0, translating Better Optical Camo has been made easier than it was before using a dedicated translation-file, `i18n.json`.
To see which texts can be translated, take a look at `i18n.default.json`, look for the strings to want to translate,
copy those into `i18n.json` and finally, translate the texts.

Better Optical Camo does not come with a `i18n.json` by itself, so if you made a translation, you only need to distribute `i18n.json`
instead of the whole `init.lua`, which allows for easier updates when people use translations.

-----

#### Key Bindings
* Toggling: Combat Gadget key (middle mouse button by default)
