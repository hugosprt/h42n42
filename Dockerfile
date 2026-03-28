FROM ocaml/opam:debian-12-ocaml-4.14

WORKDIR /app

RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
    m4 \
    pkg-config \
    libgmp-dev \
    libev-dev \
    libssl-dev \
    libpcre2-dev \
    zlib1g-dev \
    libsqlite3-dev \
    ca-certificates \
  && sudo rm -rf /var/lib/apt/lists/*

RUN opam init --reinit -y --disable-sandboxing
RUN opam update

RUN opam pin add -y js_of_ocaml 5.8.0
RUN opam pin add -y js_of_ocaml-compiler 5.8.0
RUN opam pin add -y js_of_ocaml-lwt 5.8.0
RUN opam pin add -y js_of_ocaml-tyxml 5.8.0

RUN opam install -y \
    dune \
    lwt \
    tyxml \
    js_of_ocaml=5.8.0 \
    js_of_ocaml-lwt=5.8.0 \
    js_of_ocaml-tyxml=5.8.0 \
    eliom \
    ocsigenserver

COPY --chown=opam:opam . /app

RUN opam exec -- make all
RUN opam exec -- sh -lc 'mkdir -p "$(ocamlfind query ocsigenserver)/var/run"'

EXPOSE 8080

CMD ["opam", "exec", "--", "ocsigenserver", "-c", "/app/h42n42.conf.in", "-v"]