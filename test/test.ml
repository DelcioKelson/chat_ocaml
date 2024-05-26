open Alcotest
module IO = Chat_lib.Io_handlers.IODefault
module Server = Chat_lib.Server.Server(IO)

let () =
  run "Testing chat" [
    "IO (unit)", [
      test_case "Handle output" `Quick Io_tests.test_handle_output;
      test_case "Handle input" `Quick Io_tests.test_handle_input;
      test_case "Send Message" `Quick Io_tests.test_send_message;
      test_case "Handle Message" `Quick Io_tests.test_handle_message;
      test_case "Handle acknowledgment" `Quick Io_tests.test_acknowledgment_handle_message
    ];
    
    "Chat (integration)", [
      test_case "test basic connection" `Quick Chat_tests.test_basic_connection ;
      test_case "test exclusive connections" `Quick Chat_tests.test_exclusive_connection ;
      test_case "test service persistence" `Quick Chat_tests.test_server_persistence 
    ]
  ]

(*Ensure the server is killed affter tests*)

let () = Lwt_main.run (Server.kill ~port:5000) 
