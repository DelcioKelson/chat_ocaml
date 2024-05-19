open Lwt.Syntax
open Lwt_unix
open Base

module IO = Common.Io_handlers.IODefault
module IOHandlers = Common.Io_handlers.IOHandlers(IO)
  
let listen_address = Unix.inet_addr_loopback
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
  let* (fd, _) = accept socket in
  let* () = Lwt_io.print "User connected.\n" in
  let* () = log_info "User connected" in
  let ic = Lwt_io.of_fd ~mode:Lwt_io.input fd in
  let oc = Lwt_io.of_fd ~mode:Lwt_io.output fd in
  Lwt.return (ic, oc)

let rec handle_connection socket =
  let* () = Lwt_mutex.lock connection_mutex in
  let* () = Lwt.catch
    (fun () ->
      let* (ic, oc) = accept_connection socket in
      let (ic_io,oc_io) = IO.to_generic_type (ic, oc) in
      let* () = IOHandlers.send_message  oc_io "connection established" in
      IOHandlers.handle_io (ic_io, oc_io)    )
    (fun ex -> log_error "Error handling connection" ex)
    in
  Lwt_mutex.unlock connection_mutex;
  handle_connection socket

let start listen_port =
  Lwt_main.run begin
    Lwt.catch
      (fun () ->
        let* socket = create_socket listen_address listen_port in
        let* () = Logs_lwt.info (fun m -> m "server started") in
        let* () = Lwt_io.printl "Server started\ntype exit to leave" in
        handle_connection socket
      )
      (fun ex ->
        let* () = Lwt_io.printl "Error starting server. Try again " in
        log_error "Error starting server" ex
      )
  end