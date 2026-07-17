------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})
hl.monitor({
	output = "eDP-1",
	mode = "1920x1080@60",
	position = "0x0",
	scale = 1,
})

-- Monitor-Hotplug (Kabel/Dock rein/raus) -> eDP-1 automatisch an/aus.
hl.on("monitor.added", function()
	hl.exec_cmd(ReconcileMonitors)
end)
hl.on("monitor.removed", function()
	hl.exec_cmd(ReconcileMonitors)
end)
