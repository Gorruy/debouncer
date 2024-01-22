module debouncer #(
  // This module will collect serial data
  // of data bus size and put it in parallel
  // form with first came bit as MSB
  parameter CLK_FREQ_MHZ   = 200,
  parameter GLITCH_TIME_NS = 500

)(
  input   logic clk_i,
  input   logic key_i,

  output  logic key_pressed_stb_o
);
  localparam real NOT_ROUNDED  = GLITCH_TIME_NS / ( 1000 / CLK_FREQ_MHZ );
  localparam      CLK_CYCLES   = int'($ceil(NOT_ROUNDED)) - 2;
  localparam      COUNTER_SIZE = $clog2(CLK_CYCLES) + 1;

  logic [COUNTER_SIZE - 1:0] counter;
  logic                      first_reg;
  logic                      second_reg;

  always_ff @( posedge clk_i )
   begin
    { first_reg, second_reg } <= { key_i, first_reg };
   end

  always_ff @( posedge clk_i )
    begin
      if ( !second_reg && !first_reg )
        counter <= counter + (COUNTER_SIZE)'(1);
      else 
        counter <= '0;
    end

  always_ff @( posedge clk_i )
    begin
      if ( counter == CLK_CYCLES &&
           !first_reg && !second_reg )
        key_pressed_stb_o <= 1'b1;
      else
        key_pressed_stb_o <= 1'b0;
    end
  
 
endmodule