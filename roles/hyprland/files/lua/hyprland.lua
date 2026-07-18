-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")
--
---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
-- NOTE: global (no `local`) so split-out files like main/keybinds can read them.
Terminal = "kitty"
--fileManager = "dolphin"
FileManager = "nautilus"
Menu = "hyprlauncher"
-- menu = "rofi --show drun"
Statusbar = "waybar"
Browser = "brave"

-- Split-out config lives in files/lua/modules/, deployed to ~/.config/hypr/modules/.
-- Requires the programs above, so load it after they're defined.
require("modules.monitor")
require("modules.autostart")
require("modules.environment")
require("modules.permissions")
require("modules.looks")
require("modules.input")
require("modules.keybinds")
require("modules.misc")
require("modules.window")
