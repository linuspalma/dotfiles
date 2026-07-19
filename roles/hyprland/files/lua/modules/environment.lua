-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- XWayland/HiDPI: mit xwayland.force_zero_scaling (siehe misc.lua) skaliert
-- Hyprland Qt-Fenster nicht mehr hoch -> Qt muss selbst skalieren, sonst zu klein.
-- AUTO_SCREEN_SCALE_FACTOR liest die per-Monitor-DPI vom X-Server und skaliert
-- fraktional (Dell 1.5 vs eDP-1 1). Behebt das pixelige TeamViewer.
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
