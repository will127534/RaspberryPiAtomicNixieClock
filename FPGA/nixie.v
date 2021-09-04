module NixieCounter (
    input clk,
    input rst,
    input wire [31:0] NixieBCD,
    input wire [15:0] digitpoint,
    output reg NIXIE_LE,
    output reg NIXIE_CLK,
    output NIXIE_DIN,
    input pps,
    output reg Done
    );

    wire[95:0] nixiedata_96bit;

    binarytoNixiedigit conv8(.x(NixieBCD[3:0]),.z(nixiedata_96bit[96-2:84+1])); 
    binarytoNixiedigit conv7(.x(NixieBCD[7:4]),.z(nixiedata_96bit[84-2:72+1])); 
    binarytoNixiedigit conv6(.x(NixieBCD[11:8]),.z(nixiedata_96bit[72-2:60+1])); 
    binarytoNixiedigit conv5(.x(NixieBCD[15:12]),.z(nixiedata_96bit[60-2:48+1])); 
    binarytoNixiedigit conv4(.x(NixieBCD[19:16]),.z(nixiedata_96bit[48-2:36+1])); 
    binarytoNixiedigit conv3(.x(NixieBCD[23:20]),.z(nixiedata_96bit[36-2:24+1])); 
    binarytoNixiedigit conv2(.x(NixieBCD[27:24]),.z(nixiedata_96bit[24-2:12+1])); 
    binarytoNixiedigit conv1(.x(NixieBCD[31:28]),.z(nixiedata_96bit[12-2:0+1])); 

    assign {nixiedata_96bit[0] ,nixiedata_96bit[12],nixiedata_96bit[24],nixiedata_96bit[36],nixiedata_96bit[48],nixiedata_96bit[60],nixiedata_96bit[72],nixiedata_96bit[84],nixiedata_96bit[11+0] ,nixiedata_96bit[11+12],nixiedata_96bit[11+24],nixiedata_96bit[11+36],nixiedata_96bit[11+48],nixiedata_96bit[11+60],nixiedata_96bit[11+72],nixiedata_96bit[11+84]} = digitpoint;

    wire[95:0] nixiedata_32bit ;

    function [32-1:0] bitOrder (
      input [32-1:0] data
    );
    integer i;
    begin
      for (i=0; i < 32; i=i+1) begin : reverse
          bitOrder[32-1-i] = data[i]; //Note how the vectors get swapped around here by the index. For i=0, i_out=15, and vice versa.
      end
    end
    endfunction
    
    //assign sample_rev = bitOrder(sample_in); //swap the bits.
    assign nixiedata_32bit[31:0] = bitOrder(nixiedata_96bit[96-1:64]);
    assign nixiedata_32bit[63:32] = bitOrder(nixiedata_96bit[64-1:32]);
    assign nixiedata_32bit[95:64] = bitOrder(nixiedata_96bit[32-1:0]);


    //assign nixiedata_32bit[31:0] = nixiedata_96bit[96-1:64];
    //assign nixiedata_32bit[63:32] = nixiedata_96bit[64-1:32];
    //assign nixiedata_32bit[95:64] = nixiedata_96bit[32-1:0];

    localparam IDLE = 3'b000;
    localparam SHIFT_0 = 3'b001;
    localparam SHIFT_1 = 3'b010;
    localparam START_0 = 3'b011;
    localparam START_1 = 3'b100;
    localparam START_2 = 3'b111;
    localparam END = 3'b101;
    localparam END_WAIT = 3'b110;


    reg [2:0] currentState;
    reg [2:0] nextState;

    reg [15:0] dataCounter;
    reg [95:0] nixie_data;
    reg [1:0] data_in_valid_d;

    assign NIXIE_DIN = nixie_data[95]; // send MSB first

    reg [1:0] fallingEdgePPS_d;
    wire fallingEdgePPS = (fallingEdgePPS_d == 2'b10);
    always @(posedge clk) begin
        fallingEdgePPS_d <= {fallingEdgePPS_d[0],pps};
        if (!rst) begin
            currentState <= IDLE;
            NIXIE_CLK <= 0;
            NIXIE_LE <= 1;
            dataCounter <= 0;
            nixie_data <= 0;
            Done <= 0;
            fallingEdgePPS_d <= 0;
        end
        else begin
            currentState <= nextState;
            case(currentState)
                IDLE: begin
                    if(fallingEdgePPS) begin
                        nixie_data <= nixiedata_32bit;
                        dataCounter <= 0;
                    end
                    NIXIE_LE <= 1;
                    NIXIE_CLK <= 0;
                    Done <= 0;
                end
                START_2: begin
                    NIXIE_LE <= 1;
                    NIXIE_CLK <= 0;
                end
                START_0: begin
                    NIXIE_LE <= 0;
                    NIXIE_CLK <= 0;
                end
                START_1: begin
                    NIXIE_LE <= 0;
                    NIXIE_CLK <= 1;
                end
                SHIFT_0: begin
                    NIXIE_LE <= 0;
                    NIXIE_CLK <= 1;
                    dataCounter <= dataCounter + 1;
                    nixie_data <= {nixie_data[94:0], 1'b0};
                end
                SHIFT_1: begin
                    NIXIE_LE <= 0;
                    NIXIE_CLK <= 0;
                end
                END_WAIT: begin
                    NIXIE_LE <= 0;
                    NIXIE_CLK <= 0;
                    Done <= 1;
                end
                END: begin
                    NIXIE_LE <= 1;
                    NIXIE_CLK <= 0;
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
                if(fallingEdgePPS) begin
                    nextState = START_2;
                end
            end
            START_2: begin
                nextState = START_0;
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
                if(dataCounter == 15'd95)begin
                    nextState = END_WAIT;
                end
                else begin
                    nextState = SHIFT_0;
                end
            end
            END_WAIT: begin
                if(pps)begin
                    nextState = END;
                end
                else begin
                    nextState = END_WAIT;
                end
            end
            END: begin
                nextState = IDLE;
            end
            default: begin
                nextState = IDLE;
            end
        endcase
    end
endmodule

module binarytoNixiedigit(
    input  [3:0]x,
    output [9:0]z 
    );
    reg [9:0] z /* synthesis syn_romstyle = "select_rom" */;
    always @* 
    case (x)
    4'b0000 :       //Hexadecimal 0
    z = 10'b1000000000;
    4'b0001 :       //Hexadecimal 1
    z = 10'b0000000001;
    4'b0010 :     // Hexadecimal 2
    z = 10'b0000000010;
    4'b0011 :     // Hexadecimal 3
    z = 10'b0000000100;
    4'b0100 :   // Hexadecimal 4
    z = 10'b0000001000;
    4'b0101 :   // Hexadecimal 5
    z = 10'b0000010000;
    4'b0110 :   // Hexadecimal 6
    z = 10'b0000100000;
    4'b0111 :   // Hexadecimal 7
    z = 10'b0001000000;
    4'b1000 :          //Hexadecimal 8
    z = 10'b0010000000;
    4'b1001 :       //Hexadecimal 9
    z = 10'b0100000000;
    default:     // Hexadecimal A
    z = 10'b0000000000;
    endcase
endmodule