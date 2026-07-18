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

hl.monitor({
	output = "desc:Dell Inc. DELL U3225QE F7SB684",
	mode = "3840x2160@120",
	position = "auto",
	scale = 1.5,
})

hl.monitor({
	output = "eDP-1",
	mode = "1920x1080@60",
	position = "0x0",
	scale = 1,
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
--    spaetere "on"-Aufrufe werden No-ops (Panel bleibt schwarz).
-- 2. dpms direkt aus einem Bind ist laut Doku undefined behavior.
-- Beides loest der oneshot-Timer (500ms, Wiki-Empfehlung): er feuert nach dem
-- Prop Refresh UND ausserhalb des Bind-Kontexts. KEIN
-- hl.exec_scheduled_prop_refresh_immediately() davor -- das gibt es in der
-- installierten Hyprland-Version noch nicht (nil -> Runtime-Error im Callback).
local want_closed = false

-- dpms fuer ALLE aktiven Monitore neu anwenden, nicht nur eDP-1. Noetig weil:
-- a) ein Monitor, der in eine dpms-off-Session gehotpluggt wird (standalone
--    zugeklappt -> Kabel rein), sonst schwarz bleibt -- niemand weckt ihn;
-- b) hyprland.start beim Boot am Dock feuert, bevor die externen registriert
--    sind -> reconcile entscheidet "standalone+zu" und legt per dpms off die
--    Session schlaf. Das spaetere monitor.added laeuft durch denselben Pfad
--    und weckt die externen wieder.
-- Callback liest want_closed + Monitorliste erst beim Feuern (kein Capture):
-- stale Timer wenden so immer den neuesten Stand an, mehrfaches Feuern ist
-- idempotent. "off" wird nur fuer eDP-1 dispatcht und nur, wenn kein externer
-- aktiv ist (sonst ist eDP-1 disabled und fehlt in der Liste).
-- Shadow-State des zuletzt dispatchten eDP-1-dpms. apply_dpms ist die einzige
-- dpms-Quelle, daher ist das zuverlaessig.
local edp_dpms_off = false

-- Kommt das Panel nach Re-Enable bei zugeklappter Lid mit Backlight ~0 hoch,
-- ist es per dpms "an", aber schwarz. Restore nur wenn unter 5% vom Maximum,
-- damit eine bewusst gewaehlte Helligkeit nicht ueberschrieben wird.
local BACKLIGHT_RESCUE = "sh -c 'cur=$(brightnessctl get); max=$(brightnessctl max); "
	.. '[ "$cur" -lt $((max / 20)) ] && brightnessctl -e4 set 40%\''

-- off->on-Flanke fuer eDP-1: dpms on allein weckt das Panel nicht, wenn es bei
-- geschlossener Lid re-enabled wurde (kein echter Modeset, Backlight aus).
-- Darum harter Zyklus: erst explizit off (repariert auch einen evtl.
-- desyncten Hyprland-dpms-Status), 400ms spaeter on + erzwungener Modeset +
-- Backlight-Rettung. Nur auf der Flanke, damit im Dock-Betrieb der externe
-- nicht bei jedem Lid-Oeffnen mitflackert. Der innere Timer prueft
-- want_closed erneut: klappt die Lid binnen 400ms wieder zu, bleibt off.
local function wake_edp()
	hl.dispatch(hl.dsp.dpms({ action = "off", monitor = "eDP-1" }))
	hl.timer(function()
		if want_closed then
			return
		end
		hl.dispatch(hl.dsp.dpms({ action = "on", monitor = "eDP-1" }))
		hl.dispatch(hl.dsp.force_renderer_reload())
		hl.dispatch(hl.dsp.exec_cmd(BACKLIGHT_RESCUE))
	end, { timeout = 400, type = "oneshot" })
end

local function apply_dpms()
	for _, m in ipairs(hl.get_monitors()) do
		local off = m.name == "eDP-1" and want_closed
		if m.name == "eDP-1" and edp_dpms_off and not off then
			wake_edp()
		else
			hl.dispatch(hl.dsp.dpms({ action = off and "off" or "on", monitor = m.name }))
		end
		if m.name == "eDP-1" then
			edp_dpms_off = off
		end
	end
end

local function reconcile(closed)
	if closed == nil then
		closed = lid_closed()
	end
	want_closed = closed
	if external_present() and closed then
		hl.monitor({ output = "eDP-1", disabled = true })
	else
		hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto", disabled = false })
	end
	hl.timer(apply_dpms, { timeout = 500, type = "oneshot" })
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
