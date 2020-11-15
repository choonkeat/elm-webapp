# like `make run` but with a file-watching-recompile loop
watch:
	#
	# on ./src file changes, server will exit
	# once recompile succeeds (retry every 5s), server will start
	#
	# ctrl-c to shutdown gracefully
	#
	until make compile; do sleep 5; done
	until node index.js --watch; do until make compile; do sleep 5; done; done

# like `make watch` but without file watching loop
run: compile
	node index.js

compile: elm.json package.json src/Types/Auto.elm build/Server.js public/assets/client.js

src/Types/Auto.elm: src/Types.elm
	#
	# for every type in `src/Types.elm`
	# generate a json encoder/decoder in `src/Types/Auto.elm`
	#
	# read more at https://github.com/choonkeat/elm-auto-encoder-decoder
	#
	WATCHING=false elm-auto-encoder-decoder src/Types.elm

build/Server.js: src/Server.elm src/Types.elm
	elm make src/Server.elm --output build/Server.js

public/assets/client.js: src/Client.elm src/Types.elm
	elm make src/Client.elm --output public/assets/client.js

#

install: elm.json package.json
	yes | elm install elm/url > /dev/null
	yes | elm install elm/json > /dev/null
	yes | elm install elm/http > /dev/null
	yes | elm install elm/time > /dev/null
	yes | elm install choonkeat/elm-fullstack > /dev/null
	@printf "\nready. type \`make\` to start server\n\n"

elm.json:
	yes | elm init > /dev/null

package.json:
	npm init -y
	npm install --save xhr2 full-url node-static websocket
	npm install --save-dev elm-auto-encoder-decoder
