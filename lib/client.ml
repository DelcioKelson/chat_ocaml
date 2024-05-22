open Lwt.Syntax
open Base

module IO = Io_handlers.IODefault

module Client (IO: Io_handlers.IOType) = struct
  module IOHandlers = Io_handlers.IOHandlers(IO)

  let establish_connection sockaddr =
    let* (ic, oc) = IO.open_connection sockaddr in
    let* message = IO.read_line_opt ic in
    match message with
    | Some "connection established" -> 
      let* () = IO.printf "LConnection established\n" in
      Lwt.return_ok (ic, oc)
    | Some _ | None -> 
      Lwt.fail (Failure "Connection error: unexpected response from server")

  let connect_with_timeout timeout_duration sockaddr =
    let timeout =
      let* () = Lwt_unix.sleep timeout_duration in
      Lwt.fail (Failure "Connection timed out")
    in
    let connection = establish_connection sockaddr in
    Lwt.pick [timeout; connection]

  let connect_to_server server_address server_port timeout_duration =
    let sockaddr = Unix.ADDR_INET (server_address, server_port) in
    connect_with_timeout timeout_duration sockaddr

  let start server_address server_port timeout_duration =
    Lwt_main.run(
      let* result =
        Lwt.catch
          (fun () -> connect_to_server server_address server_port timeout_duration)
          (fun ex ->
             let* () = Logs_lwt.err (fun m -> m "Failed to connect to the server: %s" (Exn.to_string ex)) in
             Lwt.return_error (Failure "Failed to connect to the server. Please try again."))
      in
      match result with
      | Ok (ic, oc) ->
          let* () = IO.printf "Type 'exit' to leave\n" in
          IOHandlers.handle_io ( ic, oc)
      | Error ex -> IO.printf "%s\n" (Exn.to_string ex)
    )
end

module ClientDefaultIO = Client(IO)
