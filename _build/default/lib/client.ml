open Lwt.Syntax
open Common

module IO = Io_handlers.IODefault

module Client (IO: Io_handlers.IOType) = struct
  module IOHandlers = Io_handlers.IOHandlers(IO)

  exception Connection_exn

  let exn_to_string = function
    | Lwt_unix.Timeout -> "Connection timed out: Another client may be connected to the server"
    | Unix.Unix_error (Unix.ECONNREFUSED, "connect", "") -> "Connection refused: Server is not available"
    | Connection_exn -> "Connection error: Connection could not be established"
    | exn -> "Unexpected error: " ^ Printexc.to_string exn

  let establish_connection sockaddr =
    let* (ic, oc) = IO.open_connection sockaddr in
    let* message = IO.read_line_opt ic in
    match message with
    | Some "Connection established" -> 
      Lwt.return_ok (ic, oc)
    | Some _ | None -> fail Connection_exn

  let connect_to_server server_address server_port timeout_connection =
    Lwt.catch
      (fun () -> 
        let sockaddr = Unix.ADDR_INET (server_address, server_port) in
        Lwt_unix.with_timeout timeout_connection  (fun () -> establish_connection sockaddr))
      (fun exn -> 
        let error_msg= exn_to_string exn in
        let* () = log_error error_msg exn in
        Lwt.return_error error_msg)

  let start ~server_address ~server_port ~timeout_connection =
    let* result = connect_to_server server_address server_port timeout_connection in
    match result with
    | Error error -> IO.printl error
    | Ok (ic, oc) ->
        let* () = IO.printl connection_established_msg in
        let* () = log_info connection_established_msg in
        let* () = IO.printl "Type 'exit' to leave" in
          IOHandlers.handle_io ( ic, oc, IO.stdin)

end
