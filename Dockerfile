FROM ocaml/opam:ubuntu-23.10-ocaml-5.0

WORKDIR /app

RUN opam init

# Install dependencies
COPY --chown=opam:opam . .

RUN opam install -y dune core lwt lwt_ppx core_unix logs

# Copy the source code
COPY . .

# Build the project
RUN eval $(opam env) && dune build
