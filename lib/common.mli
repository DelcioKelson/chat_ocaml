val connection_established_msg : string

val log_error : string -> exn -> unit Lwt.t

val log_info : string -> unit Lwt.t

val fail : exn -> 'a Lwt.t
