-- Dateityp-Erkennung für Ansible/Jinja-Templates.
-- Neovim lädt ~/.config/nvim/filetype.lua automatisch beim Setup der
-- Filetype-Erkennung (vor Plugins, vor dem ersten Datei-Read) -> genau
-- deshalb steht das hier und nicht in einer Plugin-Config.
-- Neovim kennt die Endung .j2 von Haus aus NICHT -> wir registrieren sie hier.
-- "yaml.jinja" ist ein zusammengesetzter Filetype: lädt YAML *und* Jinja.
vim.filetype.add({
	extension = {
		j2 = "jinja", -- generische Jinja-Templates: foo.conf.j2, foo.sh.j2, ...
	},
	pattern = {
		-- YAML-Jinja-Templates: foo.yml.j2 / foo.yaml.j2
		-- priority > 0 ist nötig, sonst gewinnt die .j2-Endung oben
		-- und die Datei würde nur als "jinja" statt "yaml.jinja" erkannt.
		[".*%.ya?ml%.j2"] = { "yaml.jinja", { priority = 10 } },
	},
})
