return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup({
			ensure_installed = { "markdown", "lua" },
			auto_install = true,
			ignore_install = { "javascript" },
		})

		-- Jinja files: Treesitter-YAML-Parser kann {% %} nicht parsen
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "jinja", "yaml.jinja" },
			callback = function(args)
				vim.treesitter.stop(args.buf)
			end,
		})

		-- Disable treesitter for large files (>100KB)
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
