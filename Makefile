docs:
	elm make --docs=docs.json

build:
	WATCHING=false elm-auto-encoder-decoder src/Protocol.elm
	egrep -v '^function clientContent|return dict\[key\]' bin/elm-webapp | pbcopy
	(pbpaste; \
	 printf "function clientContent(key) { const dict = "; \
	 ./bin/generate-client-content; \
	 printf "; return dict[key] }\n") > bin/elm-webapp

generate-all: build
	rm -rf templates/application; ./bin/elm-webapp application templates/application && make -C templates/application install compile
	rm -rf templates/document;    ./bin/elm-webapp document templates/document       && make -C templates/document    install compile
	rm -rf templates/element;     ./bin/elm-webapp element templates/element         && make -C templates/element     install compile
