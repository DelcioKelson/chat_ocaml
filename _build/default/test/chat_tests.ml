open Lwt.Syntax
module IO = Chat_lib.Io_handlers.IODefault
module Client = Chat_lib.Client.Client(IO)
module Server = Chat_lib.Server.Server(IO)

(* Define the server and client parameters *)
let port = 5000
let ip = Unix.inet_addr_of_string "127.0.0.1"
let timeout = 1.

let wait time = 
  Lwt_unix.sleep time

(* Test suite *)

(* Function to check if a process is running *)
let is_process_running process =
  match Lwt.state process with
  | Lwt.Sleep -> true
  | _ -> false

(* Basic connection test *)
let test_basic_connection _ () =
  (* start client instance*)

  let* () = Server.kill port in

  let client_process = 
    let* () = Lwt_unix.sleep 2.0 in
    Client.start ip port timeout in

  let is_client_running = ref false in

  let checks () = 
    let* () = wait 3.0 in
    is_client_running := is_process_running client_process ;
    Lwt.return_unit
  in
  
  let* () = Lwt.pick [(let* () = wait 1.0 in Server.start port); client_process ; checks() ] in
  (* Check if the server and client are alive *)

  let is_server_alive = Server.is_running port in
  Alcotest.(check bool) "Server should be alive" true is_server_alive;
  Alcotest.(check bool) "Client should be alive" true !is_client_running;
  Lwt.return_unit

(* Exclusive connection test *)
let test_exclusive_connection _ () =
  (* Start client processes *)
  let client1_process = Client.start ip port timeout in
  let client2_process =
    let* () = Lwt_unix.sleep timeout in
     Client.start ip port 0.5 
  in

  let is_client1_running = ref false in
  let is_client2_running = ref false in

  let wait () = 
    (* Ensure both server and client threads are alive *)
    let* () = Lwt_unix.sleep 1.0 in
    is_client1_running := is_process_running client1_process ;
    is_client2_running := is_process_running client2_process ;
    Lwt.return_unit
  in

  let* () = Lwt.pick [ Server.start port; client1_process; client2_process; wait() ] in

  let is_server_alive = Server.is_running port in
  Alcotest.(check bool) "Server should be alive" true is_server_alive;
  Alcotest.(check bool) "Client 1 should be alive" true !is_client1_running;
  Alcotest.(check bool) "Client 2 should not be alive" false !is_client2_running;

Lwt.return_unit

(* Server persistence test *)

let test_server_persistence _ () =
  (* Start the server and client processes *)
  let client1_process = 
    let lifetime = 1.0 in
    Lwt_unix.with_timeout lifetime  (fun () -> Client.start ip port timeout)
  in
  
  let client2_process =
    let* () = Lwt_unix.sleep timeout in
     Client.start ip port 0.5 
  in

  let tests =
    (* Ensure both server and client threads are alive *)
    let* () = Lwt_unix.sleep 1.0 in
    let server_alive = Server.is_running port in
    let client1_alive = is_process_running client1_process in
    let client2_alive = is_process_running client2_process in
    Alcotest.(check bool) "Server should be alive" true server_alive;
    Alcotest.(check bool) "Client 1 should not be alive" false client1_alive;
    Alcotest.(check bool) "Client 2 should be alive" true client2_alive;
    Lwt.return_unit
  in
  
  Lwt.pick [ Server.start port; client1_process; client2_process; tests ]
