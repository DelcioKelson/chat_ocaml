#!/bin/bash

# Clean previous builds
dune clean

# Check if the Docker image ocaml_chat already exists
if [[ "$(docker images -q ocaml_chat 2> /dev/null)" == "" ]]; then
  echo "Docker image ocaml_chat does not exist. Building the image..."
  docker build -t ocaml_chat .
else
  echo "Docker image ocaml_chat already exists. Skipping build."
fi

# Run the client container
docker run -it --name ocaml_client --network echo_network --rm ocaml_chat sh -c "dune exec -- chat -mode client -ip chat_server -port 9000"
