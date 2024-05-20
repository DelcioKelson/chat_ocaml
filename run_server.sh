#!/bin/bash

dune clean

docker network create echo_network

# Build the Docker image
docker build -t ocaml_chat .

# Run the Docker container
docker run -it --name chat_server -p 9000:9000 --rm --network echo_network ocaml_chat dune exec -- chat -mode server -port 9000 
