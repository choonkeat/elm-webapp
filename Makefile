docs:
	elm make --docs=docs.json

prerelease:
	# https://docs.npmjs.com/cli/v7/commands/npm-version
	npm version prerelease --preid=rc
	npm publish --tag next

templates/crud.diff: templates/crud-0/src templates/crud/src
	@diff -Npar -U 2 --exclude=Auto.elm templates/crud-0/src templates/crud/src > templates/crud.diff || printf ""
