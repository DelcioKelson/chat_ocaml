open Lwt.Syntax
open Lwt_unix
open Base

module IO = Io_handlers.IODefault

module Server (IO: Io_handlers.IOType) = struct
  module IOHandlers = Io_handlers.IOHandlers(IO)

  let listen_address = Unix.inet_addr_any
  let backlog = 10

  (* Mutex for managing the connection state *)
  let connection_mutex = Lwt_mutex.create ()

  let log_error message ex =
    Logs_lwt.err (fun m -> m "%s: %s" message (Exn.to_string ex))

  let log_info message =
    Logs_lwt.info (fun m -> m message)

  let create_socket listen_address listen_port =
    let sockaddr = ADDR_INET (listen_address, listen_port) in
    Lwt.catch
      (fun () ->
        let socket = socket PF_INET SOCK_STREAM 0 in
        let* () = bind socket sockaddr in
        listen socket backlog;
        Lwt.return socket
      )
      (fun ex ->
        let* () = log_error "Error creating socket" ex in
        Lwt.fail_with "Failed to create socket: it may already be in use."
      )

let accept_connection socket =
  let accept_result =
    Lwt.catch
      (fun () -> accept socket)
      (fun ex ->
        let* () = log_error "Error accepting connection" ex in
        Lwt.fail_with "Error accepting connection"
      )
  in
  let* (fd, _) = accept_result in
  let* () = Lwt_io.print "User connected.\n" in
  let* () = log_info "User connected" in
  let (ic,oc) = IO.fd_to_io fd in
  Lwt.return (ic, oc)

  let rec handle_connection socket =
    let* () = Lwt_mutex.lock connection_mutex in
    let* () = Lwt.catch
      (fun () ->
        let* (ic, oc) = accept_connection socket in
        let* () = IOHandlers.send_message oc "connection established" in
        IOHandlers.handle_io (ic, oc)    )
      (fun ex -> log_error "Error handling connection" ex)
      in
    Lwt_mutex.unlock connection_mutex;
    handle_connection socket

  let start listen_port =
    Lwt_main.run begin
      Lwt.catch
        (fun () ->
          let* socket = create_socket listen_address listen_port in
          let* () = Logs_lwt.info (fun m -> m "Server started and listening for connections") in
          let* () = Lwt_io.printl "Server started and listening for connections\nType 'exit' to leave." in
          handle_connection socket
        )
        (fun ex ->
          let* () = Lwt_io.printl "Error starting server. Please Try again.
           it's possible that there's already an instance of the server running " in
          log_error "Error starting server" ex
        )
    end
end

module ServerDefaultIO = Server(IO)