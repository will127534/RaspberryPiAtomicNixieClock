`timescale 1ns/1ns

`define SECOND 1000000000
`define MS 1000000



module SPI_TestBench();
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

    reg [9:0] pwm_value;
    initial pwm_value = 0;
    wire PWM_out;
    pdm pdm(
        .clk(clock),
        .PWM_in(pwm_value),
        .divider(8'd2),
        .PWM_out(PWM_out),
        .pwm_write(1'b1),
        .pwm_div_write(1'b1),
        .rst(rst)
  );
    


    initial begin
    $dumpfile("SPI_TestBench.vcd"); 
    $dumpvars(0, pdm);
    $dumpvars(0, PWM_out);
    #20
    pwm_value <= 10;
    #20000
    pwm_value <= 255;
    #20000
    pwm_value <= 256;
    #20000
    pwm_value <= 511;
    #20000
    pwm_value <= 512;
    #20000
    pwm_value <= 1023;
    #20000
    $finish;
    end
 
endmodule