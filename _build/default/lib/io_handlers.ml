open Lwt.Syntax
open Base

module type IOType = sig
  type input_channel
  type output_channel
  val stdin : input_channel
  val read_line_opt : input_channel -> string option Lwt.t
  val write_line : output_channel -> string -> unit Lwt.t
  val close_ic : input_channel -> unit Lwt.t
  val close_oc : output_channel -> unit Lwt.t
  val flush : output_channel -> unit Lwt.t
  val printf : ('a, unit, string, unit Lwt.t) format4 -> 'a
  val open_connection : 
  ?fd:Lwt_unix.file_descr ->
  ?in_buffer:Lwt_bytes.t ->
  ?out_buffer:Lwt_bytes.t ->
  Unix.sockaddr ->
  (input_channel * output_channel) Lwt.t
  val fd_to_io : Lwt_unix.file_descr -> input_channel * output_channel
  val oc_to_string : output_channel ->  string
  val ic_to_string : input_channel ->  string 
end


module IODefault : IOType = struct
  type input_channel = Lwt_io.input_channel
  type output_channel = Lwt_io.output_channel
  
  let stdin = Lwt_io.stdin
  let read_line_opt = Lwt_io.read_line_opt
  let write_line = Lwt_io.write_line
  let close_ic = Lwt_io.close
  let close_oc = Lwt_io.close
  let flush = Lwt_io.flush
  let printf = Lwt_io.printf
  let open_connection = Lwt_io.open_connection
  let fd_to_io fd = Lwt_io.of_fd ~mode:Lwt_io.input fd, Lwt_io.of_fd ~mode:Lwt_io.output fd
  let oc_to_string _oc = ""
  let ic_to_string _ic = ""
end


module IOHandlers (IO: IOType) = struct

  let log_error message ex =
    Logs_lwt.err (fun m -> m "%s: %s" message (Exn.to_string ex))

  let handle_send_error ex =
    Logs_lwt.err (fun m -> m "Error sending message: %s" (Exn.to_string ex))

  let handle_receive_error ex =
    Logs_lwt.err (fun m -> m "Error receiving message: %s" (Exn.to_string ex))

  let send_message oc msg =
    Lwt.catch
      (fun () ->
        let* () = IO.write_line oc msg in
        Logs_lwt.info (fun m -> m "Sent message: %s" msg)
      )
      handle_send_error

  let append_current_time msg =
    let start_time = Unix.gettimeofday () in
    msg ^ "|" ^ Float.to_string start_time

  let rec handle_output (input, oc) =
    let* input_message = IO.read_line_opt input in
    match input_message with
    | Some msg ->
        if String.(=) msg "exit" then
          Lwt.return_unit
        else
          let* () = send_message oc (append_current_time msg) in
          handle_output (input, oc)
    | None ->
        handle_output (input, oc)

  let calculate_rtt send_time =
    let current_time = Unix.gettimeofday () in
    current_time -. send_time

  let handle_message oc msg =
    let parts = String.split ~on:'|' msg in
    match parts with
    | [received_msg; timestamp] ->
        if String.(=) received_msg "message received" then
          let send_time = Float.of_string timestamp in
          Lwt.return (Printf.sprintf "message received; RT: %f\n" (calculate_rtt send_time))
        else
          let* () = send_message oc ("message received|" ^ timestamp) in
          Lwt.return (Printf.sprintf "Received: %s\n" received_msg)
    | _ ->
      Lwt.return (Printf.sprintf "Malformed message: %s\n" msg)
    
  let rec handle_input (ic, oc) =
    Lwt.catch
      (fun () ->
        let* received_msg = IO.read_line_opt ic in
        match received_msg with
        | Some msg ->
            let* message_to_print = handle_message oc msg in
            let* () = IO.printf "%s" message_to_print in
            handle_input (ic, oc)
        | None -> IO.printf "Other side disconnected\n%!")
      handle_receive_error

  let close_connection (ic, oc) =
    let* () = IO.printf "Closing connection\n" in
    let* () = IO.flush oc in 
    let* () = IO.close_ic ic in
    IO.close_oc oc

  let handle_io (ic, oc) =
    Lwt.finalize
      (fun () -> Lwt.pick [handle_input (ic, oc); handle_output (IO.stdin, oc)])
      (fun () ->
        Lwt.catch
          (fun () -> close_connection (ic, oc))
          (fun ex -> log_error "Error while closing connection" ex))
end
