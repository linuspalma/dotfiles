------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Externe Monitore: preferred/auto. eDP-1 steuert reconcile() unten.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Sobald ein externer Monitor da ist, wird eDP-1 KOMPLETT deaktiviert (nicht nur
-- abgedunkelt). Dadurch wandern seine Workspaces auf den externen Monitor und alle
-- Fenster erscheinen dort -- kein unsichtbarer Workspace mehr auf dem zugeklappten
-- Panel. Ist eDP-1 der einzige Monitor, bleibt/kommt er an -> nie 0 Outputs,
-- also kein Freeze. Idempotent: es wird nur geschaltet, wenn nötig -> keine Loops.
local function external_present()
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= "eDP-1" then
			return true
		end
	end
	return false
end

local function reconcile()
	if external_present() then
		hl.monitor({ output = "eDP-1", disabled = true })
	else
		hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto", disabled = false })
	end
end

reconcile() -- beim (Re)Load
hl.on("hyprland.start", reconcile) -- Boot (auch zugeklappt am Dock gestartet)
hl.on("monitor.added", reconcile) -- Dock/Kabel rein
hl.on("monitor.removed", reconcile) -- Dock/Kabel raus
