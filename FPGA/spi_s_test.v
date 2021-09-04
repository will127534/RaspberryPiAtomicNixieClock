`timescale 1ns/1ns

`define SECOND 1000000000
`define MS 1000000



module SPI_TestBench();
    wire [7:0] data_in;
    reg [7:0] data_out;
    initial data_out = 0;

    reg [7:0]testdata;
    initial testdata = 8'h1275;

    reg clock;
    initial clock = 0;

    always #(1) clock <= ~clock;
    wire rst;

    reg SCK,MO,CS;
    wire MI;
    initial SCK = 1;
    initial MO = 0;
    initial CS = 1;

    SPI_slave rpi_spi_dev(
        .clk(clock), 
        .SCK(SCK), 
        .MOSI(MO), 
        .MISO(MI), 
        .SSEL(CS), 
        .LED(),
        .byte_data_received(data_in),
        .byte_received(byte_received),
        .byte_sent(data_out)
    );

    reg [2:0] resetn_counter = 0;
    always @(posedge clock) begin
      if (!rst)
        resetn_counter <= resetn_counter + 1;
    end
    assign rst = &resetn_counter;


      reg [31:0] registers [7:0]; 
      reg [31:0] rpi_out;
      wire [39:0] data_in;
      wire rw_select = data_in[7];
      wire [31:0]rpi_data_in = data_in[39:8];
      wire [6:0] rpi_address = data_in[6:0];
      wire rpi_byte_received;

    always @(posedge clock) begin
    if (!rst) begin
      registers <= 0;
    end
    else
      if(rpi_byte_received & rw_select) begin
        registers[rpi_address] <= rpi_data_in;
      end
      else if(rpi_byte_received & ~rw_select) begin
        rpi_out <= registers[rpi_address];
      end
    end
    end

    initial begin
    $dumpfile("SPI_TestBench.vcd"); 
    $dumpvars(0, rpi_spi_dev);
    $dumpvars(0, rpi_out);
    $dumpvars(0, registers);
    #20
    CS <= 0;
    #1
    SCK <= 0;

    #3
    MO <= 1;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 1;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 0;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 1;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 1;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 1;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 0;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    MO <= 1;
    SCK <= 0;
    #3
    SCK <= 1;

    #3
    CS <= 1;
    #3
    SCK <= 1;

    #200
    $finish;
    end
 
endmodule