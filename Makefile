docs:
	elm make --docs=docs.json

build:
	WATCHING=false elm-auto-encoder-decoder src/Types.elm
	egrep -v '^function clientContent|return dict\[key\]' bin/elm-fullstack-init | pbcopy
	(pbpaste; \
	 printf "function clientContent(key) { const dict = "; \
	 ./bin/generate-client-content; \
	 printf "; return dict[key] }\n") > bin/elm-fullstack-init
