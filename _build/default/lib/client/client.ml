open Lwt.Syntax
open Base

module IO = Common.Io_handlers.IODefault
module IOHandlers = Common.Io_handlers.IOHandlers(IO)

let establish_connection sockaddr =
  let* (ic, oc) = Lwt_io.open_connection sockaddr in
  let* message = Lwt_io.read_line ic in
  match message with
  | "connection established" -> 
    let* () = Lwt_io.printl message in
     Lwt.return_ok (ic, oc)
  | _ -> Lwt.return_error (Failure "Connection error: unexpected response from server")

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
         Lwt.return_error ex)
  in
  match result with
  | Ok (ic, oc) ->
      let* () = Lwt_io.printl "type exit to leave" in
      let (ic_io,oc_io) = IO.to_generic_type (ic, oc) in
      IOHandlers.handle_io (ic_io, oc_io)
  | Error ex -> Lwt_io.printf "%s\n" (Exn.to_string ex)
  )