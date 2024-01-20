module top_tb;

  parameter NUMBER_OF_TEST_RUNS = 100;
  parameter DATA_BUS_WIDTH      = 17;

  bit                          clk;
  logic                        srst;
  bit                          srst_done;

  logic                        data;
  logic                        data_val;

  logic [DATA_BUS_WIDTH - 1:0] deser_data;
  logic                        deser_data_val;

  // flag to indicate if there is an error
  bit test_succeed;

  initial forever #5 clk = !clk;

  default clocking cb @( posedge clk );
  endclocking

  initial 
    begin
      srst <= 1'b0;
      ##1;
      srst <= 1'b1;
      ##1;
      srst <= 1'b0;
      srst_done = 1'b1;
    end

  deserializer #(
    .DATA_BUS_WIDTH ( DATA_BUS_WIDTH   )
  ) DUT ( 
    .clk_i            ( clk            ),
    .srst_i           ( srst           ),
    .deser_data_o     ( deser_data     ),
    .deser_data_val_o ( deser_data_val ),
    .data_i           ( data           ),
    .data_val_i       ( data_val       )
  );

  typedef logic queued_data_t[$:DATA_BUS_WIDTH - 1];

  mailbox #( queued_data_t ) output_data    = new();
  mailbox #( queued_data_t ) input_data     = new();
  mailbox #( queued_data_t ) generated_data = new();

  function void display_error ( input queued_data_t in,  
                                input queued_data_t out
                              );
    $error( "expected values:%p, result value:%p", in, out );

  endfunction

  task raise_transaction_strobe( logic data_to_send, int no_delay ); 
    
    // data comes at random moment
    int delay;

    delay = $urandom_range(10, 0) * !no_delay;
    ##(delay);

    data     = data_to_send;
    data_val = 1'b1;
    ## 1;
    data     = '0;
    data_val = 1'b0; 

  endtask

  task compare_data ( mailbox #( queued_data_t ) input_data,
                      mailbox #( queued_data_t ) output_data
                    );
    
    queued_data_t i_data;
    queued_data_t o_data;

    if ( input_data.num() != output_data.num() )
      begin
        $error("read and wrote amounts of data is not equal! r:%d, w:%d", output_data.num(), input_data.num() );
        test_succeed = 1'b0;
        return;
      end

    while ( input_data.num() )
      begin
        input_data.get( i_data );
        output_data.get( o_data );

        if ( i_data.size() != o_data.size() )
          begin
            display_error( i_data, o_data );
            test_succeed = 1'b0;
            return;
          end
        
        for ( int i = 0; i < DATA_BUS_WIDTH; i++ ) begin
          if ( i_data[i] !== o_data[DATA_BUS_WIDTH - 1 - i] )
            begin
              display_error( i_data, o_data );
              test_succeed = 1'b0;
              return;
            end
        end
      end
    
  endtask

  task generate_transactions ( mailbox #( queued_data_t ) generated_data );
    
    queued_data_t data_to_send;

    repeat (NUMBER_OF_TEST_RUNS) 
      begin
        data_to_send = {};

        for ( int i = 0; i < DATA_BUS_WIDTH; i++ ) begin
          data_to_send.push_back( $urandom_range( 1, 0 ) );
        end

        generated_data.put( data_to_send );
      end

  endtask

  task send_data ( mailbox #( queued_data_t ) input_data,
                   mailbox #( queued_data_t ) generated_data
                 );

    queued_data_t data_to_send;
    queued_data_t exposed_data;
    int           no_delay;

    while ( generated_data.num() )
      begin
        no_delay     = $urandom_range(1, 0); // randomly choose to ran transaction with no delays
        exposed_data = {};
        generated_data.get( data_to_send );
        
        for ( int i = 0; i < DATA_BUS_WIDTH; i++ ) begin
          raise_transaction_strobe( data_to_send[$], no_delay );
          exposed_data.push_back( data_to_send.pop_back() );
        end

        input_data.put( exposed_data );
      end

  endtask

  task read_data ( mailbox #( queued_data_t ) output_data );
    
    queued_data_t recieved_data;
    int           time_without_data;
    
    forever
      begin
        recieved_data = {};

        @( posedge clk );
        if ( deser_data_val === 1'b1 )
          begin
            recieved_data     = { << { deser_data } };
            time_without_data = 0;
            output_data.put(recieved_data);
          end
        else
          begin
            if ( time_without_data == 11*DATA_BUS_WIDTH )
              return;
            else 
              time_without_data += 1;
          end
      end

  endtask

  initial begin
    data         <= '0;
    data_val     <= 1'b0;
    test_succeed <= 1'b1;

    generate_transactions( generated_data );

    $display("Simulation started!");
    wait( srst_done );
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

