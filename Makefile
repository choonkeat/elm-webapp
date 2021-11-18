docs:
	elm make --docs=docs.json

prerelease:
	# https://docs.npmjs.com/cli/v7/commands/npm-version
	npm version prerelease --preid=rc
	npm publish --tag next

templates/crud.diff: $(shell find templates/crud/src templates/crud-foobar/src -type f)
	@diff -Npar -U 2 --exclude=Auto.elm templates/crud/src templates/crud-foobar/src > templates/crud.diff || printf ""
