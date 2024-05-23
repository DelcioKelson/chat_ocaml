module Client (_: Io_handlers.IOType) : sig
  val start : Unix.inet_addr -> int -> float -> unit Lwt.t
end
