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

-- closed: optional. Lid-Binds geben den Zustand explizit rein -- der Kernel-ACPI-
-- Status in /proc hinkt dem Switch-Event hinterher, Polling beim Lid-Event wuerde
-- racen (Oeffnen liest noch "closed" -> dpms bliebe aus). Sonst (Boot/Hotplug)
-- wird /proc gelesen.
--
-- dpms-Handling (Wiki: Dispatchers + Expanding functionality / Prop Refresh):
-- 1. hl.monitor()-Aenderungen werden erst am ENDE des laufenden Lua-Events
--    angewendet (Prop Refresh). Ein dpms direkt nach dem Enable traefe einen
--    noch disableten Output und verpufft -- Hyprlands DPMS-Status desynct,
--    spaetere "on"-Aufrufe werden No-ops (Panel bleibt schwarz). Darum wird
--    der Refresh sofort ausgefuehrt.
-- 2. dpms direkt aus einem Bind ist laut Doku undefined behavior -- darum
--    entkoppelt ueber oneshot-Timer (500ms, Wiki-Empfehlung).
-- want_closed statt Closure-Capture: kommt binnen 500ms ein neues Lid-Event,
-- wendet auch ein "alter" Timer den neuesten Zustand an.
local want_closed = false

local function reconcile(closed)
	if closed == nil then
		closed = lid_closed()
	end
	if external_present() and closed then
		hl.monitor({ output = "eDP-1", disabled = true })
	else
		hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto", disabled = false })
		hl.exec_scheduled_prop_refresh_immediately()
		want_closed = closed
		hl.timer(function()
			hl.dispatch(hl.dsp.dpms({ action = want_closed and "off" or "on", monitor = "eDP-1" }))
		end, { timeout = 500, type = "oneshot" })
	end
end

-- WICHTIG: Event-Handler gekapselt aufrufen -- hl.on uebergibt dem Callback ein
-- Argument (z.B. den Monitor bei monitor.added). Direkt als `reconcile` wuerde das
-- als `closed` ankommen und faelschlich als "zugeklappt" interpretiert.
-- config.reloaded ist BEWUSST NICHT registriert: es feuert beim Kaltstart waehrend
-- initManagers, bevor CPointerManager existiert -> dpms() => SEGV => kein Start.
hl.on("hyprland.start", function() reconcile() end) -- Boot (auch zugeklappt am Dock)
hl.on("monitor.added", function() reconcile() end) -- Dock/Kabel rein
hl.on("monitor.removed", function() reconcile() end) -- Dock/Kabel raus
hl.bind("switch:on:Lid Switch", function() reconcile(true) end, { locked = true }) -- Lid zu
hl.bind("switch:off:Lid Switch", function() reconcile(false) end, { locked = true }) -- Lid auf
