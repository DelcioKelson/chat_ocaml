open Lwt.Syntax

module IO = Chat_lib.Io_handlers.IODefault
module Client = Chat_lib.Client.Client(IO)
module Server = Chat_lib.Server.Server(IO)

let resolve_hostname hostname =
  let open Lwt_unix in
  let* addresses = getaddrinfo hostname "" [AI_FAMILY PF_INET] in
  match addresses with
  | [] -> Lwt.fail (Failure ("Unable to resolve hostname: " ^ hostname))
  | addr_info::_ -> Lwt.return addr_info.ai_addr

let parse_ip_or_hostname ip_or_hostname =
  try
    let ip = Unix.inet_addr_of_string ip_or_hostname in
    Lwt.return (Some (Unix.ADDR_INET (ip, 0)))
  with
  | Failure _ -> 
    let* sockaddr = resolve_hostname ip_or_hostname in
    Lwt.return (Some sockaddr)

    let command =
      Command.basic
        ~summary:"A simple echo server/client"
        ~readme:(fun () -> "More detailed information")
        Command.Let_syntax.(
          let%map_open mode = flag "mode" (required string) ~doc:"The mode to run in (server or client)"
          and ip_string = flag "ip" (optional_with_default "127.0.0.1" string) ~doc:"IP Address of the server (default:127.0.0.1)"
          and port = flag "port" (optional_with_default 9000 int) ~doc:"Port of the server (default:9000)"
          and timeout_duration = flag "timeout" (optional_with_default 1. float) ~doc:"The timeout for client-server connection (default:5 secs)" 
          and kill = flag "kill" (optional int) ~doc:"Kill the server" in
          fun () ->
            Lwt_main.run (
            match mode with
            | "server" -> 
              if Option.is_some kill then
                Server.kill port
              else
                Server.start port
            | "client" ->
              let* sockaddr_result = parse_ip_or_hostname ip_string in
              (match sockaddr_result with
              | Some (Unix.ADDR_INET (ip, _)) -> Client.start ip port timeout_duration
              | _ -> Lwt_io.print "Invalid IP address or hostname resolution failed\n")
            | _ -> Lwt_io.print "Invalid mode\n"
        ))
         
let () = Command_unix.run command
    