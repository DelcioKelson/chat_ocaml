module IO : module type of Io_handlers.IODefault

module Server (IO: Io_handlers.IOType) : sig
  module IOHandlers : module type of Io_handlers.IOHandlers(IO)

  val create_socket : Unix.inet_addr -> int -> Lwt_unix.file_descr Lwt.t
  val accept_connection : Lwt_unix.file_descr -> (IO.input_channel * IO.output_channel) Lwt.t
  val handle_connection : Lwt_unix.file_descr -> unit Lwt.t
  val start : int -> unit
end

module ServerDefaultIO : module type of Server(IO)

