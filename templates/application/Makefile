# like `make run` but with a file-watching-recompile loop
watch:
	#
	# on ./src file changes, server will exit
	# once recompile succeeds (retry on file changes), server will start
	#
	# ctrl-c to shutdown gracefully
	#
	until make compile; do make wait-for-changes; done
	until node index.js --watch; do until make compile; do make wait-for-changes; done; done

# like `make watch` but without file watching loop
run: compile
	node index.js

compile: elm.json package.json src/Protocol/Auto.elm build/Server.js public/assets/client.js

src/Protocol/Auto.elm: $(shell find src/Protocol.elm src/Protocol -iname '*.elm' | grep -v Auto.elm)
	#
	# generate json encoder/decoder for every type in src/Protocol
	# read more at https://github.com/choonkeat/elm-auto-encoder-decoder
	#
	EXTRA_IMPORT='Extra.Codec exposing (..)' \
	GENERATED_SRC=src \
	WATCHING=false \
	PATH='node_modules/.bin:${PATH}' \
	elm-auto-encoder-decoder `find src/Protocol.elm src/Protocol -iname '*.elm' | grep -v Auto.elm`

build/Server.js: src/*.elm src/**/*.elm
	elm make src/Server.elm --output build/Server.js

public/assets/client.js: src/*.elm src/**/*.elm
	elm make src/Client.elm --output public/assets/client.js

#

install: install-wait-for-changes elm.json package.json
	yes | elm install elm/url > /dev/null
	yes | elm install elm/json > /dev/null
	yes | elm install elm/http > /dev/null
	yes | elm install elm/time > /dev/null
	yes | elm install choonkeat/elm-webapp > /dev/null
	@printf "\nready. type \`make\` to start server\n\n"

elm.json:
	yes | elm init > /dev/null

package.json:
	npm init -y
	npm install --save xhr2 full-url node-static websocket
	npm install --save-dev elm-auto-encoder-decoder

install-wait-for-changes:
	@test "`uname`" != "Linux" || which inotifywait || (printf "\nyou will need \"inotifywait\" by installing \"inotify-tools\" with your package manager\n\n\te.g. apk add inotify-tools\n\t     apt-get install inotify-tools\n\n"; exit 1)

wait-for-changes:
	echo Waiting for file changes...
	@if test "`uname`" = "Linux"; then inotifywait -r -e close_write -e move -e create -e delete .; else node scripts/wait-for-changes.js .; fi

#

deploy-aws-lambda: FUNCTION_ZIP=$(FUNCTION_NAME).zip
deploy-aws-lambda: compile
	test -n "$(FUNCTION_NAME)" || (echo Missing FUNCTION_NAME; exit 1)
	test -n "$(S3BUCKET)" || (echo Missing S3BUCKET; exit 1)
	@echo Deploying $(FUNCTION_NAME) ...
	zip -q -r $(FUNCTION_ZIP) . -i *.js 'js/*' 'build/*' 'node_modules/*' 'public/*'
	time aws s3 cp $(FUNCTION_ZIP) s3://$(S3BUCKET)/$(FUNCTION_ZIP)
	time aws lambda update-function-code --function-name $(FUNCTION_NAME) --s3-bucket $(S3BUCKET) --s3-key $(FUNCTION_ZIP) --publish
