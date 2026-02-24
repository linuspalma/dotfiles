vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set clipboard=unnamedplus")
vim.cmd("set softtabstop=2")

-- für copy & paste mit clipboard wenn nvim über ssh läuft:
vim.g.clipboard = "osc52"
vim.o.winborder = "rounded"

vim.opt.autowrite = true
vim.opt.autowriteall = true

vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cursorline = true
-- vim.opt.cursorlineopt = "number"

vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = " Zeile nach unten" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = " Zeile nach oben" })

vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = " Zeile nach unten" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = " Zeile nach oben" })

vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2"
vim.opt.showbreak = "↪ "

vim.o.backup = true
vim.opt.backupcopy = "yes"
vim.opt.backupdir = vim.fn.stdpath("state") .. "/backup//"
