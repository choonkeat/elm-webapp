docs:
	elm make --docs=docs.json

prerelease:
	# https://docs.npmjs.com/cli/v7/commands/npm-version
	npm version prerelease --preid=rc
	npm publish --tag next