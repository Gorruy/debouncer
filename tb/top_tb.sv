module top_tb;
  
  parameter       NUMBER_OF_TEST_RUNS = 100;
  parameter       CLK_FREQ_MHZ        = 100;
  parameter       GLITCH_TIME_NS      = 50;

  localparam real NOT_ROUNDED         = GLITCH_TIME_NS / (1000 / CLK_FREQ_MHZ);
  localparam      CLK_CYCLES          = $ceil(NOT_ROUNDED) - 2;

  bit       clk;
  logic     key;
  logic     key_pressed_stb;

  // flag to indicate if there is an error
  bit       test_succeed;

  typedef struct {
    bit button_pressed;
    int total_time;
    int press_time;
  } transaction_t;

  initial forever #5 clk = !clk;

  default clocking cb @( posedge clk );
  endclocking

  debouncer #(
    .CLK_FREQ_MHZ      ( CLK_FREQ_MHZ    ),
    .GLITCH_TIME_NS    ( GLITCH_TIME_NS  )
  ) DUT ( 
    .clk_i             ( clk             ),
    .key_i             ( key             ),
    .key_pressed_stb_o ( key_pressed_stb )
  );

  mailbox #( transaction_t ) output_data    = new();
  mailbox #( transaction_t ) input_data     = new();
  mailbox #( transaction_t ) generated_data = new();

  function void display_error ( input transaction_t in,  
                                input transaction_t out
                              );
    $error( "expected values:%p, result value:%p", in, out );

  endfunction

  task raise_transaction_strobe( input int key_pressed ); 
    
    #($urandom_range(3,0));
    if ( key_pressed == CLK_CYCLES - 1 )
      key = 1;
    else
      key = $urandom_range(1, 0);
    if ( !key )
      key_pressed += 1;    

  endtask

  task compare_data ( mailbox #( transaction_t ) input_data,
                      mailbox #( transaction_t ) output_data
                    );
    
    transaction_t i_data;
    transaction_t o_data;

    while ( input_data.num() )
      begin
        input_data.get(i_data);
        output_data.get(o_data);

        if ( o_data.button_pressed != i_data.button_pressed )
          begin
            display_error( i_data, o_data );
            test_succeed = 1'b0;
            return;
          end
        else if ( o_data.press_time != i_data.press_time )
          begin
            display_error( i_data, o_data );
            test_succeed = 1'b0;
            return;
          end
      end    
  endtask

  task generate_transactions ( mailbox #( transaction_t ) generated_data );
    
    transaction_t data_to_send;

    repeat (NUMBER_OF_TEST_RUNS) 
      begin
        data_to_send.button_pressed = $urandom_range(1, 0);
        if ( data_to_send.button_pressed )
          begin
            data_to_send.total_time = $urandom_range(CLK_CYCLES*20, CLK_CYCLES + 1);
            data_to_send.press_time = $urandom_range(data_to_send.total_time - CLK_CYCLES, 0);
          end
        else
          begin
            data_to_send.total_time = $urandom_range(CLK_CYCLES*20, 0);
            data_to_send.press_time = 'x;
          end

        generated_data.put( data_to_send );
      end

  endtask

  task send_data ( mailbox #( transaction_t ) input_data,
                   mailbox #( transaction_t ) generated_data
                 );

    transaction_t data_to_send;
    int           key_pressed;

    while ( generated_data.num() )
      begin
        generated_data.get( data_to_send );
        key_pressed = 0;

        for (int i = 0; i < data_to_send.total_time; i++ )
          begin
            @( posedge clk );
            if ( data_to_send.button_pressed &&
                 i == data_to_send.press_time )
              begin
                #($urandom_range(4, 0));
                key = 1'b0;
              end
            else if ( data_to_send.button_pressed &&
                      i > data_to_send.press_time &&
                      i < data_to_send.press_time + CLK_CYCLES )
              continue;
            else
              raise_transaction_strobe(key_pressed);
          end

        input_data.put( data_to_send );
      end

  endtask

  task read_data ( mailbox #( transaction_t ) output_data );
    
    transaction_t recieved_data;
    int           time_without_data;
    
    forever
      begin
        @( posedge clk );
      end

  endtask

  initial begin
    test_succeed <= 1'b1;

    generate_transactions( generated_data );

    $display("Simulation started!");
    fork
      read_data( output_data );
      send_data( input_data, generated_data );
    join

    compare_data( input_data, output_data );
    $display("Simulation is over!");
    if ( test_succeed )
      $display("All tests passed!");
    $stop();
  end
  



endmodule

