module IO : module type of Io_handlers.IODefault

module Client (IO: Io_handlers.IOType) : sig
  module IOHandlers : module type of Io_handlers.IOHandlers(IO)

  val establish_connection : Unix.sockaddr -> (IO.input_channel * IO.output_channel, exn) result Lwt.t

  val connect_with_timeout : float -> Unix.sockaddr -> (IO.input_channel * IO.output_channel, exn) result Lwt.t

  val connect_to_server : Unix.inet_addr -> int -> float -> (IO.input_channel * IO.output_channel, exn) result Lwt.t

  val start : Unix.inet_addr -> int -> float -> unit
end

module ClientDefaultIO : module type of Client(IO)