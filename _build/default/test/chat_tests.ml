open Lwt.Syntax
module IO = Chat_lib.Io_handlers.IODefault
module Client = Chat_lib.Client.Client(IO)
module Server = Chat_lib.Server.Server(IO)

let ip = Unix.inet_addr_of_string "127.0.0.1"
let port = 5000

let wait time = Lwt_unix.sleep time

let is_process_running process =
  match Lwt.state process with
  | Lwt.Sleep -> true
  | _ -> false

let kill_process process =
  if is_process_running process then
    Lwt.cancel process

(* Test suite *)
(* Basic connection test *)
let test_basic_connection () =
  (* Start the server process *)
  let server_process = 
    let* () = wait 1.0 in
    let* () = Server.start ~port in
    wait 7.0
  in

  (* Start the client process *)
  let client_process = 
    let* () = wait 3.0 in
    Client.start ~server_address:ip ~server_port:port ~timeout_connection:1.0
  in

  (* Set a timeout for the test *)
  let test_timeout = wait 5.0 in

  (* Run the server and client processes with a timeout *)
  let process = [server_process; client_process; test_timeout] in
  Lwt_main.run (
    let* () = Lwt.choose process in
    Lwt.return_unit
  );

  (* Check if the server and client are still alive *)
  let is_service_alive = Server.is_running ~port in 
  let is_client_alive = is_process_running client_process in
  Alcotest.(check bool) "Server should be alive" true is_service_alive;
  Alcotest.(check bool) "Client should be alive" true is_client_alive;

  (* Kill the client process *)
  kill_process client_process 

(* Exclusive connection test *)
let test_exclusive_connection () =
  (* Start the server process *)
  let server_process = 
    let* () = wait 1.0 in
    let* () = Server.start ~port in
    wait 8.0
  in

  (* Start the first client process *)
  let client1_process =
    let* () = wait 3.0 in
    Client.start ~server_address:ip ~server_port:port ~timeout_connection:1.0
  in

  (* Start the second client process *)
  let client2_process =
    let* () = wait 6.0 in
    Client.start ~server_address:ip ~server_port:port ~timeout_connection:1.0
  in

  (* Set a timeout for the test *)
  let test_timeout = wait 8.0 in

  (* Run the server and client processes with a timeout *)
  let process = [server_process; client1_process; client2_process; test_timeout] in
  Lwt_main.run (
    let* () = Lwt.choose process in
    Lwt.return_unit
  );

  (* Check if the server and clients are still alive *)
  let is_service_alive = Server.is_running ~port in
  let is_client1_alive = is_process_running client1_process in 
  let is_client2_alive = is_process_running client2_process in
  Alcotest.(check bool) "Server should be alive" true is_service_alive;
  Alcotest.(check bool) "Client 1 should be alive" true is_client1_alive;
  Alcotest.(check bool) "Client 2 should not be alive" false is_client2_alive;

  (* Kill the client processes *)
  kill_process client1_process;
  kill_process client2_process

(* Server persistence test *)
let test_server_persistence () =
  (* Start the server process *)
  let server_process = 
    let* () = wait 1.0 in
    let* () = Server.start ~port in
    wait 7.0
  in

  (* Start the first client process with a timeout *)
  let client1_process =
    let* () = wait 2.0 in
    Lwt_unix.with_timeout 4.0 (fun () -> 
      Client.start ~server_address:ip ~server_port:port ~timeout_connection:1.0
    )
  in

  (* Start the second client process *)
  let client2_process =
    let* () = wait 7.0 in
    Client.start ~server_address:ip ~server_port:port ~timeout_connection:1.0
  in
  
  (* Set a timeout for the test *)
  let test_timeout = wait 7.0 in

  (* Run the server and client processes with a timeout *)
  let process = [server_process; client1_process; client2_process; test_timeout] in
  Lwt_main.run (
    let* () = Lwt.choose process in
    Lwt.return_unit
  );
  
  (* Check if the server and clients are still alive *)
  let is_service_alive = Server.is_running ~port in
  let is_client1_alive = is_process_running client1_process in 
  let is_client2_alive = is_process_running client2_process in
  Alcotest.(check bool) "Server should be alive" true is_service_alive;
  Alcotest.(check bool) "Client 1 should not be alive" false is_client1_alive;
  Alcotest.(check bool) "Client 2 should be alive" true is_client2_alive;

  (* Kill the client processes *)
  kill_process client1_process;
  kill_process client2_process
