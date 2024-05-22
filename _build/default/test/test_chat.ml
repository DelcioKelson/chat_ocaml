open Alcotest_lwt

let () =
Lwt_main.run @@
  run "Utils" [
    "IO_handlers", [
      test_case "Handle output" `Quick Io_handlers_tests.test_handle_output;
      test_case "Send Message" `Quick Io_handlers_tests.test_send_message;
      test_case "Handle Message" `Quick Io_handlers_tests.test_handle_message;
      test_case "Handle acknowledgment" `Quick Io_handlers_tests.test_acknowledgment_handle_message;
    ]
  ]