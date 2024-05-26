open Lwt.Syntax
open Lwt_unix
open ExtLib

module Server (IO: Io_handlers.IOType) = struct
  module IOHandlers = Io_handlers.IOHandlers(IO)

  let listen_address = Unix.inet_addr_any
  let backlog = 1

  let pid_file_name port = Printf.sprintf "/tmp/server_%d.pid" port

  (* Mutex for managing the connection state *)
  let connection_mutex = Lwt_mutex.create ()

  let log_error message ex =
    Logs_lwt.err (fun m -> m "%s: %s" message (Printexc.to_string ex))

  let log_info message =
    Logs_lwt.info (fun m -> m message)

  let delete_file file_name =
    if Sys.file_exists file_name then Sys.remove file_name

  let is_running ~port:port =
    let pid_file = pid_file_name port in
    try 
      let pid = int_of_string (input_file pid_file) in
      Unix.kill pid 0;
      true
    with _ -> false

  let create_socket listen_address port =
    let sockaddr = ADDR_INET (listen_address, port) in
    Lwt.catch
      (fun () ->
        let socket = socket PF_INET SOCK_STREAM 0 in
        setsockopt socket SO_REUSEADDR true;
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
    let* () = Lwt_io.print "Client connected.\n" in
    let* () = log_info "Client connected" in
    let (ic,oc) = IO.fd_to_io fd in
    Lwt.return (ic, oc)

  let rec handle_connection socket =
    let* () = Lwt_mutex.lock connection_mutex in
    let* () = Lwt.catch
      (fun () ->
        let* (ic, oc) = accept_connection socket in
        let* () = IOHandlers.send_message oc "connection established" in
        IOHandlers.handle_io (ic, oc, IO.stdin)
      )
      (fun ex -> log_error "Error handling connection" ex)
    in
    Lwt_mutex.unlock connection_mutex;
    handle_connection socket

  let create_server port =
    Lwt.catch
      (fun () ->
        let* socket = create_socket listen_address port in
        let* () = Logs_lwt.info (fun m -> m "Server started and listening for connections") in
        let* () = Lwt_io.printl "Server started and listening for connections\nType 'exit' to leave." in
        handle_connection socket
      )
      (fun ex ->
        let* () = Lwt_io.printf "Error starting server. Please try again. %s: " (Printexc.to_string ex) in
        log_error "Error starting server" ex
      )

  let start ~port:port =
    let pid_file = pid_file_name port in
    if is_running ~port:port then
      Lwt_io.printl "Server is already running."
    else
      let* () = 
        let* () = Lwt_io.printl "Starting server..." in
        let pid = Int.to_string (Unix.getpid ()) in
        output_file ~filename:pid_file ~text:pid;
        Lwt.finalize
          (fun () -> create_server port)
          (fun () -> Lwt.return (delete_file pid_file))
      in
      Lwt.return_unit
  
  let kill ~port:port =
    if not (is_running ~port:port) then
      Lwt_io.printl "Server is not running."
    else
      let pid_file = pid_file_name port in
      try
        let pid = int_of_string (input_file pid_file) in
        (* Send termination signal to the server process *)
        Unix.kill pid Sys.sigterm;
        delete_file pid_file;
        Lwt_io.printl "Server stopped."
      with _ ->
        Lwt_io.printl "Error trying to stop the server."    

end
