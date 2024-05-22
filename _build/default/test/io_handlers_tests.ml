
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
  Alcotest.(check string) "send_message" message output;
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

    

  (*
let%test_unit "handle_input" =
  let ic = ref ["message1"; "message2"] in
  let oc = ref [] in
  let (ic_io, oc_io) = Mockio.MockIO.to_io_channels (ic, oc) in
  let%lwt () = TestIOHandlers.handle_input (ic_io, oc_io) in
  let expected_output = ["message1"; "message2"] in
  assert (!oc = expected_output)

  let%test_unit "handle_output" =
  let ic = ref ["input1"; "input2"] in
  let oc = ref [] in
  let (ic_io, oc_io) = Mockio.MockIO.to_io_channels (ic, oc) in
  let%lwt () = TestIOHandlers.handle_output oc_io in
  let expected_output = ["input1"; "input2"] in
  assert (!oc = expected_output)

let%test_unit "handle_message - message received" =
  let ic = ref [] in
  let oc = ref [] in
  let (ic_io, oc_io) = Mockio.MockIO.to_io_channels (ic, oc) in
  let msg = "message received|123.456" in
  let%lwt () = TestIOHandlers.handle_message oc_io msg in
  let expected_output = ["message received|123.456"] in
  assert (!oc = expected_output)

let%test_unit "handle_message - message sent" =
  let ic = ref [] in
  let oc = ref [] in
  let (ic_io, oc_io) = Mockio.MockIO.to_io_channels (Lwt_io.pipe ()) in
  let msg = "message sent|123.456" in
  let%lwt () = TestIOHandlers.handle_message oc_io msg in
  let expected_output = ["message sent|123.456"] in
  assert (!oc = expected_output)

let%test_unit "handle_io - normal operation" =
  let ic = ref ["input1"; "input2"] in
  let oc = ref [] in
  let (ic_io, oc_io) = Mockio.MockIO.to_io_channels (Lwt_io.pipe ()) in
  let%lwt () = TestIOHandlers.handle_io (ic_io, oc_io) in
  let expected_output = ["input1"; "input2"] in
  assert (!oc = expected_output)


  
  let test_handle_output () =
    let ic = ref "exit" in
    let oc = ref "" in
    let* () = IOHandlers.handle_output oc in
    Alcotest.(check string) "handle_output" "" !oc;
    Lwt.return_unit
  
  let test_handle_input () =
    let ic = ref "message received|12345.678" in
    let oc = ref "" in
    let* () = IOHandlers.handle_input (ic, oc) in
    Alcotest.(check string) "handle_input" "message received|12345.678" !oc;
    Lwt.return_unit
  
  let () =
    let open Alcotest_lwt in
    Lwt_main.run @@ run "IOHandlers tests"
      [
        "send_message", [test_case "send_message" `Quick test_send_message];
        "handle_message", [test_case "handle_message" `Quick test_handle_message];
        "handle_output", [test_case "handle_output" `Quick test_handle_output];
        "handle_input", [test_case "handle_input" `Quick test_handle_input];
      ]
  *)