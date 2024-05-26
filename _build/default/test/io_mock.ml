open Lwt.Syntax

module MockIO : Chat_lib.Io_handlers.IOType = struct
  type input_channel = string Lwt_mvar.t
  type output_channel = string Lwt_mvar.t

  let stdin = Lwt_mvar.create ("test message")
  
  let read_line_opt ic =
    Lwt.catch
      (fun () -> 
        let* line = Lwt_mvar.take ic in 
        Lwt.return (Some line))
      (fun _ -> Lwt.return None)

  let write_line oc msg =
    Lwt_mvar.put oc msg

  let close_ic _ic = Lwt.return_unit
  let close_oc _oc = Lwt.return_unit
  let flush _oc = Lwt.return_unit
  let printf fmt = Printf.ksprintf (fun s -> Lwt.return (print_endline s)) fmt
  let open_connection ?fd:_ ?in_buffer:_ ?out_buffer:_ _addr =
    let ic = Lwt_mvar.create_empty () in
    let oc = Lwt_mvar.create_empty () in
    Lwt.return (ic, oc)
  
  let fd_to_io _fd = (Lwt_mvar.create_empty (), Lwt_mvar.create_empty ())
    
  let oc_to_string oc_var = 
    let oc_content = Lwt_mvar.take_available oc_var |> Option.default "" in
    oc_content

  let ic_to_string ic_var =
    let ic_content = Lwt_mvar.take_available ic_var |> Option.default "" in
    ic_content

 end
  