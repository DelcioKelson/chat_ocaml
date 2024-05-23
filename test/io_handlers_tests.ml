
open Lwt.Syntax

module IOMock = Io_mock.MockIO
module TestIOHandlers = Chat_lib.Io_handlers.IOHandlers(IOMock)

let fd = Lwt_unix.of_unix_file_descr Unix.stdin

let timeout =
  let* () = Lwt_unix.sleep 0.1 in
  Lwt.return_unit

let is_greater_than x y =
  x > y

let test_send_message _ () =
  let (_, oc) = IOMock.fd_to_io fd in
  let message = "Hello, world!" in
  let send_message_process = TestIOHandlers.send_message oc message in
  let* () = Lwt.pick [timeout; send_message_process] in
  let output = IOMock.oc_to_string oc in
  let expected_output = "Hello, world!" in
  Alcotest.(check string) "send_message" expected_output output;
  Lwt.return_unit

let test_handle_output _ () =
  let stdin = IOMock.stdin in 
  let (_, oc) = IOMock.fd_to_io fd in
  let handle_output_process = TestIOHandlers.handle_output (stdin, oc) in
  let* () = Lwt.pick [timeout; handle_output_process] in
  let  output = IOMock.oc_to_string oc in
  let expected_output = "test message|.*" in
  (* Check that the output matches the expected pattern *)
  let pattern = Str.regexp expected_output in
  let matches = Str.string_match pattern output 0 in
  Alcotest.(check bool) "Output should match expected pattern" true matches;
  Lwt.return_unit

  let test_handle_input _ () =
    let stdin = IOMock.stdin in
    let (_, oc) = IOMock.fd_to_io fd in
    let handle_input_process = TestIOHandlers.handle_input (stdin, oc) in
    let* () = Lwt.pick [timeout; handle_input_process] in
    let output = IOMock.ic_to_string stdin in
    let expected_output = "" in
    Alcotest.(check string) "Stdin should be empty" expected_output output;
    Lwt.return_unit

  let test_handle_message _ () =
    let (_, oc) = IOMock.fd_to_io fd in
  
    let test_case msg expected_output expected_sent_msg =
      let* result = TestIOHandlers.handle_message oc msg in
      Alcotest.(check string) "Response message" expected_output result;
      let sent_msg = IOMock.oc_to_string oc in
      Alcotest.(check string) "Sent message" expected_sent_msg sent_msg;
      Lwt.return_unit
    in
    Lwt_list.iter_s (fun (msg, expected_output, expected_sent_msg) ->
      test_case msg expected_output expected_sent_msg
    ) [
      ("Hello, world!|123456.789", "Received: Hello, world!\n", "message received|123456.789");
      ("Malformed message", "Malformed message: Malformed message\n", "");
    ]
  
  let test_acknowledgment_handle_message _ () =
    let (_, oc) = IOMock.fd_to_io fd in
    let msg = "message received|123456.789" in
    let* result = TestIOHandlers.handle_message oc msg in
    let pattern = Str.regexp "^message received; RT: [0-9]+\\.[0-9]+\n$" in
    let matches = Str.string_match pattern result 0 in
    Alcotest.(check bool) "Output should match expected pattern" true matches;
    Lwt.return_unit