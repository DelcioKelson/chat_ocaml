open Alcotest_lwt


let () =
Lwt_main.run @@
  run "Testing chat" [
    "IO_handlers (unit)", [
      test_case "Handle output" `Quick Io_handlers_tests.test_handle_output;
      test_case "Handle input" `Quick Io_handlers_tests.test_handle_input;
      test_case "Send Message" `Quick Io_handlers_tests.test_send_message;
      test_case "Handle Message" `Quick Io_handlers_tests.test_handle_message;
      test_case "Handle acknowledgment" `Quick Io_handlers_tests.test_acknowledgment_handle_message;
    ];
    "Chat (integration)", [
      test_case "test basic connection" `Quick Chat_tests.test_basic_connection ;
      (*test_case "test exclusive connections" `Quick Chat_tests.test_exclusive_connection ;
      test_case "test service persistence" `Quick Chat_tests.test_server_persistence ;*)
    ]
  ]

