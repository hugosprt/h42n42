APP_NAME := h42n42
SRC := src/main.eliom

SERVER_DIR := _server
CLIENT_DIR := _client

TYPE_INFO := $(SERVER_DIR)/main.type_mli
SERVER_MOD := $(SERVER_DIR)/main.cmo
CLIENT_JS := static/$(APP_NAME).js

COMMON_PACKAGES := \
	-thread \
	-package js_of_ocaml \
	-package js_of_ocaml-lwt \
	-package js_of_ocaml-tyxml \
	-package lwt \
	-package tyxml

SERVER_PACKAGES := -package eliom.server
CLIENT_PACKAGES := -package eliom.client

all: $(SERVER_MOD) $(CLIENT_JS)

$(TYPE_INFO): $(SRC)
	mkdir -p $(SERVER_DIR) $(CLIENT_DIR) static
	eliomc $(SERVER_PACKAGES) $(COMMON_PACKAGES) -infer $<

$(SERVER_MOD): $(SRC) $(TYPE_INFO)
	mkdir -p $(SERVER_DIR) $(CLIENT_DIR) static
	eliomc $(SERVER_PACKAGES) $(COMMON_PACKAGES) -c $<

$(CLIENT_JS): $(SRC) $(TYPE_INFO)
	mkdir -p $(SERVER_DIR) $(CLIENT_DIR) static
	js_of_eliom $(CLIENT_PACKAGES) $(COMMON_PACKAGES) -o $@ $<

clean:
	rm -rf $(SERVER_DIR) $(CLIENT_DIR)

fclean: clean
	rm -f $(CLIENT_JS)

re: fclean all

.PHONY: all clean fclean re