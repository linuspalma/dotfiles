return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local ts = require("nvim-treesitter")

		-- main branch: setup() nimmt KEINE ensure_installed/auto_install/ignore_install mehr.
		ts.setup()

		-- Parser installieren (main branch: über install(), nicht über setup()).
		-- Wichtig, sonst nutzt Neovim seinen älteren gebündelten Parser -> passt nicht
		-- zu den neueren Queries von nvim-treesitter ("Invalid field name ...").
		ts.install({
			"lua",
			"markdown",
			"markdown_inline",
			"bash",
			"yaml",
			"python",
			"json",
			"vim",
			"vimdoc",
		})

		-- main branch startet Highlighting NICHT automatisch -> per FileType starten.
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local ft = vim.bo[args.buf].filetype

				-- Jinja: Treesitter-YAML-Parser kann {% %} nicht parsen -> aus lassen.
				if ft == "jinja" or ft == "yaml.jinja" then
					return
				end

				pcall(vim.treesitter.start, args.buf)
			end,
		})

		-- Große Dateien (>100KB): kein Treesitter.
		vim.api.nvim_create_autocmd("BufReadPost", {
			callback = function(args)
				local max_filesize = 100 * 1024
				local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
				if ok and stats and stats.size > max_filesize then
					vim.treesitter.stop(args.buf)
				end
			end,
		})
	end,
}
