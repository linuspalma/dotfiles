----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
		disable_hyprland_logo = true, -- If true disables the random hyprland logo / anime girl background. :(
	},
})

-- XWayland skaliert auf HiDPI (Dell @ scale 1.5) nicht selbst -> Hyprland wuerde
-- das fertige Bitmap hochskalieren = pixelig (z.B. TeamViewer, ein Qt5-X11-Prog).
-- force_zero_scaling schaltet dieses Upscaling ab; die Toolkit-Skalierung
-- uebernimmt QT_AUTO_SCREEN_SCALE_FACTOR (siehe environment.lua).
-- Ref: https://wiki.hypr.land/Configuring/XWayland/
hl.config({
	xwayland = {
		force_zero_scaling = true,
	},
})
