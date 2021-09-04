`timescale 1ns/1ns

`define SECOND 1000000000
`define MS 1000000



module Counter_TestBench();
    reg clock;
    initial clock = 0;

    always #(1) clock <= ~clock;
    wire rst;
    reg [2:0] resetn_counter = 0;
    always @(posedge clock) begin
      if (!rst)
        resetn_counter <= resetn_counter + 1;
    end
    assign rst = &resetn_counter;

    wire [31:0] counter;
    reg inputsig;
    initial inputsig = 0;
    CounterModule cm(
      .inputsig(inputsig),
      .clk(clock),
      .rst(rst),
      .falling_rising(1'b0),
      .counter(counter),
      .trigger()
      );

    initial begin
    $dumpfile("Counter_TestBench.vcd"); 
    $dumpvars(0, cm);
    $dumpvars(0, counter);
    #20
    inputsig <= 1;
    #200
    inputsig <= 1;
    #200
    inputsig <= 0;
    #200
    inputsig <= 1;
    #200
    inputsig <= 0;
    #50
    inputsig <= 1;
    #200
    inputsig <= 0;
    #200
    $finish;
    end
 
endmodule