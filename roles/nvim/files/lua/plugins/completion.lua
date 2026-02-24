return {
	{
		"saghen/blink.cmp",
		version = "*",
		opts = {
			keymap = {
				preset = "enter",
				["<Tab>"] = { "select_next", "fallback" },
				["<S-Tab>"] = { "select_prev", "fallback" },
			},
			apperence = {
				nerd_font_vartiant = "mono",
			},
			completion = {
				documentation = {
					auto_show = false,
					-- auto_show_delay_ms = 300,
				},
			},
			signature = { enable = true },
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},
		},
	},
}
