vim.filetype.add({
	pattern = {
		[".*/templates/.*%.yml"] = "yaml.jinja",
		[".*/templates/.*%.yaml"] = "yaml.jinja",
		[".*/templates/.*%.j2"] = "jinja",
	},
})
