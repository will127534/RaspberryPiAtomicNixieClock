module delayPPS (
    input clk,
    input pps_in,
    output pps_out,
    input rst
    );
    localparam IDLE = 2'b00;
    localparam WAIT = 2'b01;
    localparam PULSE = 2'b10;

    //Delay the PPS for 300ms
    reg [19:0] delay_counter;
    reg [19:0] pulse_counter;

    reg [19:0] delay_counter_overflow;
    reg [19:0] pulse_counter_overflow;

    reg [1:0] currentState;
    reg [1:0] nextState;

    assign pps_out = (currentState == PULSE);

    reg pps_d;
    reg pps_d2;
    always @(posedge clk) begin
        pps_d <= pps_in;
        pps_d2 <= pps_d;
        if (!rst) begin
            currentState <= IDLE;
            delay_counter_overflow <= 20'h1386;
            pulse_counter_overflow <= 20'h1F4;
            delay_counter <= 0;
            pulse_counter <= 0;
        end
        else begin
            currentState <= nextState;
            case(currentState)
                IDLE: begin
                    delay_counter <= 0;
                    pulse_counter <= 0;
                end
                WAIT: begin
                    delay_counter <= delay_counter + 1;
                end
                PULSE: begin
                    pulse_counter <= pulse_counter + 1;
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
                if(pps_d2 == 0 & pps_d == 1) begin
                    nextState = WAIT;
                end
            end
            WAIT: begin
                if(delay_counter == delay_counter_overflow)begin
                    nextState = PULSE;
                end
            end
            PULSE: begin
                if(pulse_counter == pulse_counter_overflow)begin
                    nextState = IDLE;
                end
            end
            default: begin
                nextState = IDLE;
            end
        endcase
    end
endmodule