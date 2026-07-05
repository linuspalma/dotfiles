-- liste mit möglichen language servern:
-- https://mason-registry.dev/registry/list
return {
	{
		"williamboman/mason.nvim",
		config = true,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"html",
					"cssls",
					"svelte",
					"pyright",
					"ansiblels",
					"bashls",
					-- "yamlls",
					"marksman",
					"docker_language_server",
					"jinja_lsp",
				},
				-- automatic_enable = true ist v2-Default -> installierte Server werden
				-- automatisch via vim.lsp.enable() aktiviert. Kein manuelles enable nötig.
			})
		end,
	},
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					javascript = { "prettier" },
					typescript = { "prettier" },
					javascriptreact = { "prettier" },
					typescriptreact = { "prettier" },
					css = { "prettier" },
					html = { "prettier" },
					json = { "prettier" },
					yaml = { "prettier" },
					markdown = { "prettier" },
					lua = { "stylua" },
					python = { "black" },
				},
				format_on_save = {
					timeout_ms = 500,
					lsp_fallback = true,
				},
			})
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"prettier",
					"stylua",
					"black",
					-- nvim-treesitter (main branch) kompiliert Parser aus Quellcode
					-- und braucht dafür die tree-sitter CLI.
					"tree-sitter-cli",
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "williamboman/mason-lspconfig.nvim" },
		config = function()
			-- Diagnostics Config
			vim.diagnostic.config({
				virtual_lines = {
					current_line = true,
				},
				signs = {
					text = {
						-- ●
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
						[vim.diagnostic.severity.INFO] = " ",
					},
					numhl = {
						[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
						[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
						[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
						[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
					},
				},
			})

			-- Keybindings
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local opts = { buffer = args.buf }
					vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
					vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
					vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
					vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
					vim.keymap.set(
						"n",
						"<leader>f",
						function() require("conform").format({ async = true, lsp_fallback = true }) end,
						opts
					)
				end,
			})

			-- Spezielle Config für lua_ls
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							checkThirdParty = false,
						},
					},
				},
			})

			-- Jinja LSP: nur die Filetypes überschreiben, damit er auch bei
			-- yaml.jinja greift (Default ist nur "jinja"). Das *Aktivieren*
			-- aller Server übernimmt mason-lspconfig via automatic_enable.
			vim.lsp.config("jinja_lsp", {
				filetypes = { "jinja", "yaml.jinja" },
			})
		end,
	},
}
