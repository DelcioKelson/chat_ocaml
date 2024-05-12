open Lwt

let server_address = Unix.inet_addr_loopback
let server_port = 9000

let rec receive_loop conn =
  Lwt_io.read_line_opt conn >>= function
  | Some msg ->
      let splited_msg = Util.split_msg msg in
      Lwt_io.printf "%s: %s\n%!" (List.nth splited_msg 0) (List.nth splited_msg 1) >>= fun () ->
      receive_loop conn
  | None ->
      Lwt_io.printf "Server disconnected\n%!" >>= fun () ->
      Lwt.return_unit

let send_loop conn =
  let rec loop () =
    Lwt_io.read_line_opt Lwt_io.stdin >>= function
    | Some msg ->
        Lwt_io.write_line conn msg >>= loop
    | None ->
        Lwt.return_unit
  in
  loop ()

let client () =
  let sockaddr = Unix.ADDR_INET (server_address, server_port) in
  Lwt_io.open_connection sockaddr >>= fun (ic, oc) ->
  Lwt.async (fun () -> receive_loop ic);
  send_loop oc

let start () =
  Lwt_main.run (client ())
