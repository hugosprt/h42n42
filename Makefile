NAME := h42n42
SERVER_LIB := _server/$(NAME).cma
CLIENT_JS := static/$(NAME).js

SERVER_FLAGS := -ppx -thread \
	-package eliom.server \
	-package lwt \
	-package tyxml

CLIENT_FLAGS := -ppx -thread \
	-package eliom.client \
	-package bigstringaf \
	-package js_of_ocaml \
	-package js_of_ocaml-lwt \
	-package js_of_ocaml-tyxml \
	-package js_of_ocaml-ppx \
	-package lwt \
	-package tyxml

all: $(SERVER_LIB) $(CLIENT_JS)

$(SERVER_LIB): src/main.eliom
	mkdir -p _server _client static
	eliomc $(SERVER_FLAGS) -a -o $@ $<

$(CLIENT_JS): src/main.eliom
	mkdir -p _server _client static
	js_of_eliom $(CLIENT_FLAGS) -jsopt +bigstringaf/runtime.js -o $@ $<

clean:
	rm -rf _server _client

fclean: clean
	rm -f $(CLIENT_JS)

re: fclean all

.PHONY: all clean fclean re
