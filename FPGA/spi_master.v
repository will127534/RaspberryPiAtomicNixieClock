module SPI_MASTER (
    output reg SCK,
    input MI,
    output MO,
    output reg CS,
    input [31:0] data_in,
    input data_in_valid,
    output [31:0] data_out,
    output reg data_out_valid,
    input rst,
    input clk,
    input [6:0]bitCount
    );

    localparam IDLE = 3'b000;
    localparam SHIFT_0 = 3'b001;
    localparam SHIFT_1 = 3'b010;
    localparam START_0 = 3'b011;
    localparam START_1 = 3'b100;
    localparam END = 3'b101;

    reg [2:0] currentState;
    reg [2:0] nextState;

    reg [4:0] dataCounter;
    reg [15:0] dataInStored;
    reg [31:0] dataOutStored;

    reg [1:0] data_in_valid_d;

    assign MO = dataInStored[15]; // send MSB first
    assign data_out = dataOutStored;
    always @(posedge clk) begin
        data_in_valid_d <= {data_in_valid_d[0],data_in_valid};
        if (!rst) begin
            currentState <= IDLE;
            SCK <= 0;
            CS <= 1;
            dataOutStored <= 0;
            dataCounter <= 0;
            dataInStored <= 0;
        end
        else begin
            currentState <= nextState;
            case(currentState)
                IDLE: begin
                    if(data_in_valid) begin
                        dataInStored <= data_in;
                        dataCounter <= 0;
                    end
                    CS <= 1;
                    SCK <= 0;
                end
                START_0: begin
                    CS <= 0;
                    SCK <= 0;
                end
                START_1: begin
                    CS <= 0;
                    SCK <= 1;
                end
                SHIFT_0: begin
                    CS <= 0;
                    dataOutStored <= {dataOutStored[31:0], MI};
                    SCK <= 1;
                end
                SHIFT_1: begin
                    CS <= 0;
                    dataCounter <= dataCounter + 1;
                    dataInStored <= {dataInStored[14:0], 1'b0};
                    SCK <= 0;
                end
                END: begin
                    CS <= 1;
                    SCK <= 0;
                end
                default: begin
                    
                end
            endcase
        end
    end

    always @(*) begin
        nextState = currentState;
        case(currentState)
            IDLE: begin
                if(data_in_valid_d == 2'b01) begin
                    nextState = START_0;
                end
                data_out_valid = 0;
            end
            START_0: begin
                nextState = START_1;
            end
            START_1: begin
                nextState = SHIFT_0;
            end
            SHIFT_0: begin
                nextState = SHIFT_1;
            end
            SHIFT_1: begin
                if(dataCounter == bitCount)begin
                    nextState = END;
                end
                else begin
                    nextState = SHIFT_0;
                end
            end
            END: begin
                nextState = IDLE;
                data_out_valid = 1;
            end
            default: begin
                nextState = IDLE;
            end
        endcase
    end
endmodule