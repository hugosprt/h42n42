NAME := h42n42
SRC_ELIOM := src/main.eliom
SRC_ML := src/main.ml
JS_BUILD := _build/default/src/main.bc.js
JS_OUT := static/game.js

all: $(JS_OUT)

$(SRC_ML): $(SRC_ELIOM)
	cp $(SRC_ELIOM) $(SRC_ML)

$(JS_BUILD): $(SRC_ML) src/dune dune-project
	dune build $(JS_BUILD)

$(JS_OUT): $(JS_BUILD)
	cp $(JS_BUILD) $(JS_OUT)

clean:
	- dune clean
	rm -f $(SRC_ML)

fclean: clean
	rm -f $(JS_OUT)

re: fclean all

.PHONY: all clean fclean re
