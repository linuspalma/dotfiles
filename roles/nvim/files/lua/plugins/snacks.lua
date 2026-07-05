return {
	"folke/snacks.nvim",
	priority = 1000,
	keys = {
		{ "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
		{ "<leader>fg", function() Snacks.picker.grep() end, desc = "Grep (live)" },
		{ "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
		{ "<leader>gf", function() Snacks.lazygit.log_file() end, desc = "Lazygit Current File History" },
		{ "<leader>gl", function() Snacks.lazygit.log() end, desc = "Lazygit Log (cwd)" },
		{ "<leader>e", function() Snacks.explorer() end, desc = "Explorer(snacks)" },
		{
			"<leader>o",
			function()
				local ft = vim.bo.filetype
				if ft == "snacks_picker_list" or ft == "snacks_picker_input" then
					vim.cmd("wincmd p") -- vom explorer zum code wechseln
				else
					local explorer = Snacks.picker.get({ source = "explorer" })[1]
					if explorer then
						explorer:focus() -- explorer ist offen --> reinspringen
					else
						Snacks.explorer() -- explorer ist  zu --> oeffnen
					end
				end
			end,
		},
	},
	lazy = false,
	---@type snacks.Config
	opts = {
		animate = { enable = true },
		bigfile = { enabled = true },
		dashboard = { enabled = true },
		explorer = { enabled = true },
		indent = { enabled = true },
		input = { enabled = true },
		image = { enabled = true },
		picker = { enabled = true },
		notifier = { enabled = true },
		lazygit = { enabled = true },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = true },
		statuscolumn = { enabled = true },
		words = { enabled = true },
	},
}
