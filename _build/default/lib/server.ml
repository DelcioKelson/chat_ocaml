open Lwt.Syntax
open Lwt_unix
open ExtLib
open Common

module Server (IO: Io_handlers.IOType) = struct
  module IOHandlers = Io_handlers.IOHandlers(IO)

  exception Socket_creation_exception
  exception Connection_accepting_exn

  let exn_to_string = function
    | Socket_creation_exception -> "Socket creation error"
    | Connection_accepting_exn -> "Error accepting connection"
    | _ -> "Unknown error"

  let listen_address = Unix.inet_addr_any
  let backlog = 1

  let pid_file_name port = Printf.sprintf "/tmp/server_%d.pid" port

  (* Mutex for managing the connection state *)
  let connection_mutex = Lwt_mutex.create ()

  let delete_file file_name =
    if Sys.file_exists file_name then Sys.remove file_name

  let create_socket listen_address port =
    let sockaddr = ADDR_INET (listen_address, port) in
    Lwt.catch
      (fun () ->
        let socket = socket PF_INET SOCK_STREAM 0 in
        let* () = bind socket sockaddr in
        listen socket backlog;
        setsockopt socket SO_REUSEADDR true;
        Lwt.return socket
      )
      (fun ex -> 
        let* () = log_error "create_socket: Error creating socket" ex in
        fail Socket_creation_exception 
      )

  let rec handle_connection socket =
    let* () = Lwt_mutex.lock connection_mutex in
    let* (ic, oc) =  
      Lwt.catch
      (fun () ->
        let* (fd, _) = accept socket in
        Lwt.return (IO.fd_to_channels fd) 
      )
      (fun ex -> 
        let* () =  log_error "handle_connection: Error accepting the connection" ex in
        fail Connection_accepting_exn)
    in
    let* () = IOHandlers.send_message oc connection_established_msg in
    let* () = Lwt_io.printl "Client connected." in
    let* () = log_info "Client connected" in
    let* () = IOHandlers.handle_io (ic, oc, IO.stdin) in
    Lwt_mutex.unlock connection_mutex;
    handle_connection socket

  let create_server port =
    Lwt.catch
      (fun () ->
        let* socket = create_socket listen_address port in
        let start_message = Printf.sprintf "Server started and listening for connections on port %d" port in
        let* () = Lwt_io.printl start_message in
        let* () = log_info start_message  in
        let* () = Lwt_io.printl ("Type 'exit' to leave.") in
        handle_connection socket
      )
      (fun ex ->
        let error_msg = "Server error: " ^ exn_to_string ex in
        let* () = log_error error_msg ex in 
        Lwt.return_error error_msg
      )

  let is_running ~port:port =
    let pid_file = pid_file_name port in
    try 
      let pid = int_of_string (input_file pid_file) in
      Unix.kill pid 0;
      true
    with _ -> false

  let start ~port:port =
    let pid_file = pid_file_name port in
    if is_running ~port:port then
      Lwt_io.printl "Server is already running."
    else
      let pid = Int.to_string (Unix.getpid ()) in
      output_file ~filename:pid_file ~text:pid;
      let* result = create_server port in
      match result with
      | Error error -> Lwt_io.printl error
      | _ -> Lwt.return_unit
  
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