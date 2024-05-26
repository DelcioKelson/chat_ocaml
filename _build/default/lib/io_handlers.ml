open Lwt.Syntax
open Base
open Common
open Printf

module type IOType = sig
  type input_channel
  type output_channel
  val stdin : input_channel
  val read_line_opt : input_channel -> string option Lwt.t
  val write_line : output_channel -> string -> unit Lwt.t
  val close_ic : input_channel -> unit Lwt.t
  val close_oc : output_channel -> unit Lwt.t
  val printl : string -> unit Lwt.t
  val open_connection : 
  ?fd:Lwt_unix.file_descr ->
  ?in_buffer:Lwt_bytes.t ->
  ?out_buffer:Lwt_bytes.t ->
  Unix.sockaddr ->
  (input_channel * output_channel) Lwt.t
  val fd_to_channels : Lwt_unix.file_descr -> input_channel * output_channel
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
  let printl = Lwt_io.printl
  let open_connection = Lwt_io.open_connection
  let fd_to_channels fd = Lwt_io.of_fd ~mode:Lwt_io.input fd, Lwt_io.of_fd ~mode:Lwt_io.output fd
  let oc_to_string _oc = ""
  let ic_to_string _ic = ""
end

module IOHandlers (IO: IOType) = struct

  let append_current_time msg =
    let start_time = Unix.gettimeofday () in
    msg ^ "|" ^ Float.to_string start_time

  let calculate_rtt send_time =
    let current_time = Unix.gettimeofday () in
    current_time -. send_time
  
    let send_message oc msg =
    Lwt.catch
      (fun () ->
        let* () = IO.write_line oc msg in
        Logs_lwt.info (fun m -> m "Sent message: %s" msg)
      )
      (fun ex -> log_error "Error while sending message" ex)

  let handle_message oc msg =
    let parts = String.split ~on:'|' msg in
    match parts with
    | [received_msg; timestamp] ->
        if String.(=) received_msg "message received" then
          let send_time = Float.of_string timestamp in
          Lwt.return (sprintf "message received; RT: %f" (calculate_rtt send_time))
        else
          let* () = send_message oc ("message received|" ^ timestamp) in
          Lwt.return (sprintf "Received: %s" received_msg)
    | _ ->
      Lwt.return (sprintf "Malformed message: %s" msg)
    
  let rec handle_input (ic, oc) =
    Lwt.catch
      (fun () ->
        let* received_msg = IO.read_line_opt ic in
        match received_msg with
        | Some msg ->
            let* message_to_print = handle_message oc msg in
            let* () = IO.printl message_to_print in
            handle_input (ic, oc)
        | None -> IO.printl "Other side disconnected")
      (fun ex -> log_error "Error while reading message" ex)

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
    
  let close_connection (ic, oc) =
    let* () = IO.printl "Closing connection" in
    Lwt.catch
      (fun () -> Lwt.join [IO.close_ic ic; IO.close_oc oc])
      (fun ex -> log_error "Error while closing connection" ex)

    let handle_io (ic, oc,stdin) =
      Lwt.finalize
        (fun () -> Lwt.pick [handle_input (ic, oc); handle_output (stdin, oc)])
        (fun () ->close_connection (ic, oc))

end
