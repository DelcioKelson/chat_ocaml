open Lwt

let listen_address = Unix.inet_addr_loopback
let listen_port = 9000
let backlog = 10

(* Client type *)
type client = {
  id: int;
  oc: Lwt_io.output_channel;
}

(* Mutable state for storing clients *)
let clients : client list ref = ref []

(* Broadcast a message to all clients except the sender *)
let broadcast_message sender msg =
  List.iter (fun client ->
    let msg_with_id = Printf.sprintf "Client %d | %s" sender.id msg in
    if client.id <> sender.id then Lwt_io.write_line client.oc msg_with_id |> Lwt.ignore_result
  ) !clients

(* Handle connection from a client *)
let rec handle_connection sender ic oc =
  Lwt_io.read_line_opt ic >>= function
  | None ->
      clients := List.filter (fun client -> client.id <> sender.id) !clients;
      Logs_lwt.info (fun m -> m "Connection closed for client %d" sender.id)
  | Some msg ->
      Logs_lwt.info (fun m -> m "Received: %s from client %d" msg sender.id) >>= fun () ->
      broadcast_message sender msg;
      handle_connection sender ic oc

(* Accept a new client connection *)
let accept_connection (fd, _) =
  let ic = Lwt_io.of_fd ~mode:Lwt_io.input fd in
  let oc = Lwt_io.of_fd ~mode:Lwt_io.output fd in
  let client = { id = Random.int 100; oc } in
  clients := client :: !clients;
  Lwt.on_failure (handle_connection client ic oc) (fun e -> Logs.err (fun m -> m "Error for client %d: %s" client.id (Printexc.to_string e)));
  Logs_lwt.info (fun m -> m "Connection accepted for client %d" client.id)

(* Create a socket for the server *)
let create_socket () =
  let open Lwt_unix in
  let sockaddr = ADDR_INET (listen_address, listen_port) in
  let socket = socket PF_INET SOCK_STREAM 0 in
  bind socket sockaddr >>= fun () ->
  listen socket backlog;
  Lwt.return socket

(* Create the server and continuously accept client connections *)
let create_server socket =
  let rec accept_forever () =
    Lwt_unix.accept socket >>= fun conn ->
    accept_connection conn >>= fun () ->
    accept_forever ()
  in
  accept_forever ()

(* Start the server *)
let start () =
  Lwt_main.run begin
    Logs_lwt.info (fun m -> m "Starting server") >>= fun () ->
    create_socket () >>= fun socket ->
    create_server socket
  end
