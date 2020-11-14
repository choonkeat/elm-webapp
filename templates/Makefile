watch: compile
	until node index.js --watch; do until make compile; do sleep 5; done; done

run: compile
	node index.js

compile: elm.json package.json build/Server.js public/assets/client.js

build/Server.js: src/Server.elm src/Types.elm
	elm make src/Server.elm --output build/Server.js

public/assets/client.js: src/Client.elm src/Types.elm
	elm make src/Client.elm --output public/assets/client.js

#

install: elm.json package.json
	elm install elm/url
	elm install elm/json
	elm install elm/http
	elm install elm/time
	elm install choonkeat/elm-fullstack

elm.json:
	elm init

package.json:
	npm init -y && npm install --save xhr2 full-url node-static websocket
