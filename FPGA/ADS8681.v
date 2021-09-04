module ADC8681 (
    input rst,
    input clk,
    output CS,
    output SCK,
    output MOSI,
    input MISO,
    output debug,
    output [63:0] ADC_data_all,
    output [63:0] timestamp_all,
    output reg dataRead,
    input fifo_full,
    input pps,
    output reg [15:0] pps_tag_timestamp
    );

    localparam STARTUP = 5'b00000;
    localparam INITIAL = 5'b00001;
    localparam INITIAL_TRANSFER = 5'b00010;
    localparam START = 5'b00011;
    localparam START_TRANSFER = 5'b00100;
    localparam READ = 5'b00101;
    localparam READ_TRANSFER = 5'b00110;
    localparam READ_WAIT = 5'b00111;

    reg [31:0] data_in;
    reg data_in_valid;

    wire [31:0] data_out;
    wire data_out_valid;

    reg [31:0] read_register_address;
    
    reg [15:0] adc_data_in[3:0];
    reg [15:0] adc_timestamp[3:0];

    assign ADC_data_all = {adc_data_in[0],adc_data_in[1],adc_data_in[2],adc_data_in[3]};
    assign timestamp_all = {adc_timestamp[0],adc_timestamp[1],adc_timestamp[2],adc_timestamp[3]};

    reg [15:0] timestamp;
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

        .bitCount(6'd31)
    );

    reg [5:0] currentState;
    reg [5:0] nextState;
    reg [31:0] startupDelay;
    reg [4:0] readCount;
    reg [9:0] divcounter;
    reg [9:0] counter_value;
    reg [3:0] readCounter;
    wire readNextValue = (divcounter == counter_value);
    wire dataRead_4 = (readCounter == 4'd3);
    assign debug = readNextValue;
    always @(posedge clk) begin
        if (!rst) begin
            currentState <= STARTUP;
            startupDelay <= 0;
            read_register_address <= 32'h00000000;
            dataRead <= 0;
            divcounter <= 0;
            counter_value <= 10'd199;
            timestamp <= 0;
            readCounter <= 0;
            pps_tag_timestamp <= 0;
        end
        else begin
            if(pps) pps_tag_timestamp <= timestamp;
            if(readNextValue) begin
                divcounter <= 0;
            end
            else begin
                divcounter <= divcounter + 1;
            end

            if(pps) begin
                timestamp <= 0;
            end
            else begin
                if(readNextValue) begin 
                    timestamp <= timestamp + 1;
                end
            end


            currentState <= nextState;
            case(currentState)
                STARTUP: begin
                    startupDelay <= startupDelay + 1;
                end
                INITIAL: begin
                    data_in <= 32'h00000000;
                    data_in_valid <= 1;
                end
                INITIAL_TRANSFER: begin
                    data_in_valid <= 0;
                end
                READ: begin
                    data_in <= 32'h00000000;
                    data_in_valid <= 1;
                end
                READ_TRANSFER: begin
                    data_in_valid <= 0;
                    if(data_out_valid) begin
                        //ADC_data <= data_out;
                        adc_data_in[readCounter] <= data_out[31:16];
                        adc_timestamp[readCounter] <= timestamp;
                        readCounter <= readCounter+1;
                        if(dataRead_4) begin
                            dataRead <= 1;
                            readCounter <= 0;
                        end
                    end
                end
                READ_WAIT: begin
                    dataRead <= 0;
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
                    nextState = READ;
                end
            end
            READ: begin
                nextState = READ_TRANSFER;
            end
            READ_TRANSFER: begin
                if(data_out_valid) begin
                    nextState = READ_WAIT;
                end
            end
            READ_WAIT: begin
                if(readNextValue & ~fifo_full) begin
                    nextState = READ;
                end
            end
            default: begin
            end
        endcase
    end
endmodule