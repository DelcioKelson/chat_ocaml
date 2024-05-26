let connection_established_msg = "Connection established"

let log_error message ex =
  Logs_lwt.err (fun m -> m "%s: %s" message (Printexc.to_string ex))

let log_info message =
  Logs_lwt.info (fun m -> m "%s" message)

let fail exn =
  Lwt.fail exn