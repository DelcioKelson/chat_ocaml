module Server (_: Io_handlers.IOType) : sig
  val start : int -> unit Lwt.t
  val kill : int -> unit Lwt.t
  val is_running : int -> bool
end

