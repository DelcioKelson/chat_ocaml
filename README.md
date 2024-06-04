# Ocaml chat
Simple one on one chat written in ocaml, using lwt lib.

## Execution
    
To run the application, you have two different ways:

1. Running as a Standalone Tool

2. Running within Containers

### Running the Project as a Standalone Tool

With the standalone tool, you can start both the client and server. Follow the steps below to get started:

#### Prerequisites
Ensure you have the following packages installed. You can install them using **opam**:

```sh
opam install -y dune core lwt lwt_ppx core_unix logs extlib alcotest

```

#### Steps to Run the Project
#### 1. Start the Server
- Navigate to the root directory of the project and execute the following command to start the server:

```sh
dune exec -- chat -mode server -port 5000
```

This command will run the server on port 5000.

#### 2. Start the Client

- Once the server is running, you can start the client by executing:

```sh
dune exec -- chat -mode client -port 5000 -ip localhost
```

This command will run the client and connect it to the server running on localhost.

#### Stopping the Server
- To kill the server, you can use the following command:

```sh
dune exec -- chat -mode server -kill 5000
```

This will kill the server process running on port 5000.

#### Testing the Project
- To test the project, follow any specific testing instructions provided in the project's documentation or run the test suite using:


```sh
dune runtest
```

This command will execute the tests defined in the project.


### Running the Project within Containers

#### Prerequisites
- Ensure Docker is installed and running on your system.

#### Steps to Run the Project
##### 1. Start the Server Container

- Navigate to the root directory of the project and execute the server.sh script to start the server container. Open a terminal and run:

```sh
./server.sh
```

- This script will build and run the server container, setting up the necessary environment for the server to operate.

#### 2. Start the Client Container

- Once the server container is up and running, you can start the client container. In the same root directory, execute the client.sh script by running:

```sh
./client.sh
```
- This script will build and run the client container, allowing it to interact with the server container.

#### Additional Information
- Both server.sh and client.sh should have execute permissions. If you encounter permission issues, you can grant execute permissions by running:

```sh
chmod +x server.sh client.sh
```

### Functional Requirements

1. **Application Modes:**
   - The application should be able to start in two modes: server mode and client mode.
   - In server mode, the application waits for a client to connect.
   - In client mode, the application connects to a server using the provided IP address or hostname.

2. **Message Exchange:**
   - Both the server and the client should be able to send and receive messages.
   - The receiving side must automatically acknowledge the receipt of each message with a "message received" indication.
   - The sending side must display the roundtrip time for the acknowledgment.

3. **Connection Termination:**
   - The client should be able to terminate the connection at any time.
   - After the client terminates the connection, the server should continue to wait for another client to connect.

4. **User Interface:**
   - The application should provide a user interface, which can be a simple console interface.

### Non-Functional Requirements

1. **Platform Compatibility:**
   - The application must be able to be compiled and run on Linux.

2. **Programming Language:**
   - The application must be implemented in OCaml.

3. **Library Usage:**
   - The application can use any third-party general-purpose libraries such as extlib, containers, lwt, etc.

4. **Performance:**
   - The application should provide timely roundtrip time calculations for message acknowledgments.

5. **Robustness:**
   - The application should handle unexpected situations gracefully, such unexpected terminations.
   - Error handling should be implemented to ensure the application remains stable and provides meaningful error messages.

6. **Code Simplicity and Maintainability:**
   - The application should be easy to understand, maintain, and extend.



