-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
	hl.exec_cmd(Statusbar)
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
	-- Fallback: KDE polkit agent (bei Problemen mit hyprpolkitagent, z.B. Nextcloud-Login-Prompt)
	-- Benötigt Paket polkit-kde-agent
	-- hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
	hl.exec_cmd("gotify-desktop")
	hl.exec_cmd("awww-daemon &")
	hl.exec_cmd("nextcloud --background")
	-- Beim Boot Monitor-Zustand herstellen (docked -> eDP-1 aus).
	hl.exec_cmd(ReconcileMonitors)
end)
