FROM ubuntu:24.04

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive
ENV OPAMYES=1

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    m4 \
    pkg-config \
    bubblewrap \
    libev-dev \
    libgmp-dev \
    libssl-dev \
    zlib1g-dev \
    libsqlite3-dev \
    libgdbm-dev \
    && rm -rf /var/lib/apt/lists/*

RUN printf '\n' | sh -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)"

RUN opam init --yes --disable-sandboxing
RUN opam switch create ocreet-4.14.1 4.14.1

RUN eval $(opam env --switch=ocreet-4.14.1) && \
    opam install -y \
      eliom \
      ocsigenserver \
      ocsipersist-dbm \
      js_of_ocaml \
      js_of_ocaml-lwt \
      js_of_ocaml-tyxml \
      tyxml \
      lwt \
      ocamlfind

COPY . .

RUN opam exec -- make all

EXPOSE 8080

CMD ["opam", "exec", "--", "ocsigenserver", "-c", "/app/h42n42.conf.in", "-v"]