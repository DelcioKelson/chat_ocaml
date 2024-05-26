module Server (_: Io_handlers.IOType) : sig
  val start : port:int -> unit Lwt.t
  val kill : port:int -> unit Lwt.t
  val is_running : port:int -> bool
end

