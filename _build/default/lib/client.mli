module Client (_: Io_handlers.IOType) : sig
  val start : server_address:Unix.inet_addr -> server_port:int -> timeout_connection:float -> unit Lwt.t
end
