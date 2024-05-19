let parse_ip ip_string =
  try Some (Unix.inet_addr_of_string ip_string)
  with Failure _ -> None

let command =
  Command.basic
    ~summary:"A simple echo server/client"
    ~readme:(fun () -> "More detailed information")
    Command.Let_syntax.(
      let%map_open mode = flag "mode" (required string) ~doc:"The mode to run in (server or client)"
      and ip_string = flag "ip" (optional_with_default "127.0.0.1" string) ~doc:"IP Address of the server (default:127.0.0.1)"
      and port = flag "port" (optional_with_default 9000 int) ~doc:"Port of the server (default:9000)"
      and timeout_duration = flag "timeout" (optional_with_default 5. float) ~doc:"The timeout for client-server connection (default:5 secs)" in
      fun () ->
        match mode with
        | "server" -> Server.start port
        | "client" ->
          (match parse_ip ip_string with
          | Some ip -> Client.start ip port timeout_duration
          | _ -> Printf.printf "Invalid IP address\n")
        | _ -> Printf.printf "Invalid mode\n"
    )

let () = Command_unix.run command