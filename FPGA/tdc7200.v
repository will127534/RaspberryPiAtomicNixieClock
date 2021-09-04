module TDC7200 (
    input rst,
    input clk,
    output reg en,
    input interrupt,
    output CS,
    output SCK,
    output MOSI,
    input MISO,
    output debug,
    output [23:0] TIME1,
    output [23:0] TIME2,
    output [23:0] CLOCK_COUNT1,
    output [23:0] CALIBRATION1,
    output [23:0] CALIBRATION2,
    output reg dataRead
    );

    localparam STARTUP = 5'b00000;
    localparam INITIAL = 5'b00001;
    localparam INITIAL_TRANSFER = 5'b00010;
    localparam START = 5'b00011;
    localparam START_TRANSFER = 5'b00100;
    localparam READ = 5'b00101;
    localparam READ_TRANSFER = 5'b00110;
    localparam READ_WAIT = 5'b00111;
    reg [15:0] data_in;
    reg data_in_valid;

    wire [31:0] data_out;
    wire data_out_valid;
    reg [6:0] bitCount;

    reg [15:0] read_registers[4:0];
    reg [31:0] read_registers_values[4:0];

    assign TIME1        = read_registers_values[0];
    assign CLOCK_COUNT1 = read_registers_values[1];
    assign TIME2        = read_registers_values[2];
    assign CALIBRATION1 = read_registers_values[3];
    assign CALIBRATION2 = read_registers_values[4];

    assign debug = data_in_valid;
    SPI_MASTER spi_m(
        .SCK(SCK),
        .MI(MISO),
        .MO(MOSI),
        .CS(CS),
        .rst(rst),
        .clk(clk),

        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_out(data_out),
        .data_out_valid(data_out_valid),

        .bitCount(bitCount)
    );

    reg [5:0] currentState;
    reg [5:0] nextState;
    reg [31:0] startupDelay;
    reg [4:0] readCount;
    always @(posedge clk) begin
        if (!rst) begin
            currentState <= STARTUP;
            en <= 0;
            startupDelay <= 0;
            bitCount <= 6'd15;
            read_registers[0] <= 16'h1000;
            read_registers[1] <= 16'h1100;
            read_registers[2] <= 16'h1200;
            read_registers[3] <= 16'h1B00;
            read_registers[4] <= 16'h1C00;
            dataRead <= 0;
        end
        else begin
            currentState <= nextState;
            case(currentState)
                STARTUP: begin
                    en <= 1;
                    startupDelay <= startupDelay + 1;
                end
                INITIAL: begin
                    data_in <= 16'h4002;//h4100
                    data_in_valid <= 1;
                end
                INITIAL_TRANSFER: begin
                    data_in_valid <= 0;
                end
                START: begin
                    data_in <= 16'h4003;
                    data_in_valid <= 1;
                    bitCount <= 6'd15;
                end
                START_TRANSFER: begin
                    data_in_valid <= 0;
                    dataRead <= 0;
                end
                READ: begin
                    data_in <= read_registers[readCount];
                    data_in_valid <= 1;
                    bitCount <= 6'd31;
                end
                READ_TRANSFER: begin
                    data_in_valid <= 0;
                    if(data_out_valid) begin
                        readCount <= readCount + 1;
                        read_registers_values[readCount] <= data_out;
                    end
                end
                READ_WAIT: begin
                    readCount <= 0;
                    dataRead <= 1;
                end
                default: begin
                end
            endcase
        end
    end

    always @(*) begin
        nextState = currentState;
        case(currentState)
            STARTUP: begin
                if (startupDelay == 32'hFFFF) begin
                    nextState = INITIAL;
                end
            end
            INITIAL: begin
                nextState = INITIAL_TRANSFER;
            end
            INITIAL_TRANSFER: begin
                if(data_out_valid) begin
                    nextState = START;
                end
            end
            START: begin
                nextState = START_TRANSFER;
            end
            START_TRANSFER: begin
                if(interrupt) begin
                    nextState = READ;
                end
            end
            READ: begin
                nextState = READ_TRANSFER;
            end
            READ_TRANSFER: begin
                if(data_out_valid) begin
                    if(readCount == 5'd4) begin
                        nextState = READ_WAIT;
                    end
                    else begin
                        nextState = READ;
                    end
                end
            end
            READ_WAIT: begin
                if(~interrupt) begin
                    nextState = START;
                end
            end
            default: begin
            end
        endcase
    end
endmodule