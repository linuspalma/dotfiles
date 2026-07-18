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

-- Regel (extern x lid):
--   extern da + lid zu   -> eDP-1 AUS  (Workspaces wandern auf den externen)
--   extern da + lid auf  -> eDP-1 an   (Dual-Screen)
--   kein extern + lid auf-> eDP-1 an
--   kein extern + lid zu -> eDP-1 an, aber dpms off (abgedunkelt, kein Panik)
-- eDP-1 wird also NUR deaktiviert wenn extern+zu -> nie 0 Outputs -> kein Freeze.
-- Beim Aktivieren wird dpms explizit gesetzt, weil ein re-enable das Backlight
-- sonst nicht wiederherstellt (Output aktiv, aber schwarz).
local LID_STATE = "/proc/acpi/button/lid/LID/state"

local function external_present()
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= "eDP-1" then
			return true
		end
	end
	return false
end

local function lid_closed()
	local f = io.open(LID_STATE, "r")
	if not f then
		return false
	end
	local s = f:read("*a") or ""
	f:close()
	return s:find("closed") ~= nil
end

local function reconcile()
	local closed = lid_closed()
	if external_present() and closed then
		hl.monitor({ output = "eDP-1", disabled = true })
	else
		hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto", disabled = false })
		hl.dispatch(hl.dsp.dpms({ action = closed and "off" or "on", monitor = "eDP-1" }))
	end
end

hl.on("hyprland.start", reconcile) -- Boot (auch zugeklappt am Dock)
hl.on("config.reloaded", reconcile) -- hyprctl reload
hl.on("monitor.added", reconcile) -- Dock/Kabel rein
hl.on("monitor.removed", reconcile) -- Dock/Kabel raus
hl.bind("switch:on:Lid Switch", function() reconcile() end, { locked = true }) -- Lid zu
hl.bind("switch:off:Lid Switch", function() reconcile() end, { locked = true }) -- Lid auf
