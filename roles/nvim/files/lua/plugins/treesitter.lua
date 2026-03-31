return {
  "nvim-treesitter/nvim-treesitter",
  branch = 'master',
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require 'nvim-treesitter.configs'.setup {
      modules = {},
      sync_install = false,
      ensure_installed = { "markdown", "lua" },
      auto_install = true,
      ignore_install = { "javascript" },
      highlight = { enable = true,
        disable = function(lang, buf)
          local ft = vim.bo[buf].filetype
          if ft == "jinja" or ft == "yaml.jinja" then
            return true
          end
          local max_filesize = 100 * 1024 -- 100 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end
        end
      },
      indent = { enable = true }
    }
  end
}
