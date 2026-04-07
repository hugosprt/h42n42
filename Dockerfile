FROM ubuntu:24.04

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive
ENV OPAMYES=1

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y \
    build-essential \
    libev-dev \
    pkg-config \
    libgmp-dev \
    libssl-dev \
    zlib1g-dev \
    bubblewrap \
    m4 \
    libsqlite3-dev \
    libgdbm-dev \
    curl \
    unzip \
    git \
    rsync \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN printf "\n" | bash -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)"

RUN opam init --yes --disable-sandboxing
RUN opam switch create ocreet-4.14.1 4.14.1

RUN eval $(opam env) && \
    opam install -y \
      dune \
      eliom \
      ocsigenserver \
      js_of_ocaml \
      js_of_ocaml-lwt \
      js_of_ocaml-tyxml \
      js_of_ocaml-ppx \
      tyxml \
      lwt \
      ocamlfind \
      ocsipersist-sqlite \
      ocsipersist-sqlite-config

COPY . .

RUN opam exec -- make all

EXPOSE 8080

RUN mkdir -p /app/data

CMD ["opam", "exec", "--", "ocsigenserver", "-c", "/app/h42n42.conf.in", "-v"]