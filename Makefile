docs:
	elm make --docs=docs.json

build:
	WATCHING=false elm-auto-encoder-decoder src/Protocol.elm
	egrep -v '^function clientContent|return dict\[key\]' bin/elm-webapp | pbcopy
	(pbpaste; \
	 printf "function clientContent(key) { const dict = "; \
	 ./bin/generate-client-content; \
	 printf "; return dict[key] }\n") > bin/elm-webapp

template-generate-all:
	make template-clean template-generate GENTYPE=application
	make template-clean template-generate GENTYPE=document
	make template-clean template-generate GENTYPE=element

template-clean:
	rm -rf templates/$(GENTYPE)

template-generate: build
	./bin/elm-webapp $(GENTYPE) templates/$(GENTYPE)
	make -C templates/$(GENTYPE) install
	ln -s ../../../src/Webapp templates/$(GENTYPE)/src/Webapp
	grep -v choonkeat/elm-webapp templates/$(GENTYPE)/elm.json > templates/$(GENTYPE)/elm.json2
	mv templates/$(GENTYPE)/elm.json2 templates/$(GENTYPE)/elm.json
	make -C templates/$(GENTYPE) compile
