open Lwt.Syntax
open Lwt_unix
open Stdlib

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

  let write_pid_file pid_file =
    let pid = Unix.getpid () in
    (*write the pid in a file*)
    let oc = open_out pid_file in
    output_string oc (Int.to_string pid);
    close_out oc

  let read_pid_file pid_file =
    if Sys.file_exists pid_file then
      let ic = open_in pid_file in
      let pid = int_of_string (input_line ic) in
      close_in ic;
      Some pid
    else
      None

  let delete_pid_file pid_file =
    if Sys.file_exists pid_file then Sys.remove pid_file

  let is_running port =
    let pid_file = pid_file_name port in
    match read_pid_file pid_file with
    | Some pid ->
      (try Unix.kill pid 0; true with Unix.Unix_error (Unix.ESRCH, _, _) -> false)
    | None -> false

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
        IOHandlers.handle_io (ic, oc)
      )
      (fun ex -> log_error "Error handling connection" ex)
    in
    Lwt_mutex.unlock connection_mutex;
    handle_connection socket

  let create_server listen_port =
    Lwt.catch
      (fun () ->
        let* socket = create_socket listen_address listen_port in
        let* () = Logs_lwt.info (fun m -> m "Server started and listening for connections") in
        let* () = Lwt_io.printl "Server started and listening for connections\nType 'exit' to leave." in
        handle_connection socket
      )
      (fun ex ->
        let* () = Lwt_io.printf "Error starting server. Please try again. %s: " (Printexc.to_string ex) in
        log_error "Error starting server" ex
      )

  let start listen_port =
    let pid_file = pid_file_name listen_port in
    if is_running listen_port then
      Lwt_io.printl "Server is already running."
    else
      let* () = 
        let* () = Lwt_io.printl "Starting server..." in
        write_pid_file pid_file;
        Lwt.finalize
          (fun () -> create_server listen_port)
          (fun () -> Lwt.return (delete_pid_file pid_file))
      in
      Lwt.return_unit
  
  let kill listen_port =
    if not (is_running listen_port) then
      Lwt_io.printl "Server is not running."
    else
    let pid_file = pid_file_name listen_port in
    match read_pid_file pid_file with
    | Some pid ->
      Unix.kill pid Sys.sigterm;
      Lwt_io.printl "Server stopped."
    | None ->
      Lwt_io.printl "Server is not running."
end
