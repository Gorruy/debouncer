module deserializer #(
  // This module will collect serial data
  // of data bus size and put it in parallel
  // form with first came bit as MSB
  parameter CLK_FREQ_MHZ   = 150,
  parameter GLITCH_TIME_NS = 10

)(
  input  logic clk_i,
  input  logic key_i,
  input  logic key_pressed_stb_o,
);
  localparam real NOT_ROUNDED = 1000 / CLK_FREQ_MHZ * 10
  localparam CLK_CYCLES       = $ceil(NOT_ROUNDED);

  int counter;

  always_ff @( posedge clk_i )
    begin
      if ( counter == CLK_CYCLES )
        key_pressed_stb_o <= 1'b1;
      else if ( !key_i )
        counter <= counter + 1;
    end
  
  always_ff @( posedge clk_i )
    begin
      
    end
 
endmodule