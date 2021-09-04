`timescale 1ns/1ns

`define SECOND 1000000000
`define MS 1000000



module SPI_TestBench();
    reg [7:0] data_in;
    wire [7:0] data_out;
    initial data_in = 0;

    reg clock;
    initial clock = 0;

    always #(1) clock <= ~clock;
    wire rst;

    wire SCK,MO,CS;
    reg data_in_valid,MI;
    initial data_in_valid = 0;
    initial MI = 0;
    wire data_out_valid;
    SPI_slave spi_s(
        .SCK(SCK),
        .MI(MI),
        .MO(MO),
        .CS(CS),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .rst(rst),
        .clk(clock)
    );

    reg [2:0] resetn_counter = 0;
    always @(posedge clock) begin
      if (!rst)
        resetn_counter <= resetn_counter + 1;
    end
    assign rst = &resetn_counter;

    initial begin
    $dumpfile("SPI_TestBench.vcd"); 
    $dumpvars(0, spi_m);
    $dumpvars(0, data_out);
    #20
    data_in_valid <= 1;
    data_in <= 8'd55;
    #200
    $finish;
    end
 
endmodule