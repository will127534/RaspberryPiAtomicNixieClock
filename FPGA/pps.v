module pulsepersecond (
    input clk_in,
    input [23:0] counter_value,
    output clk_out,
    output pps_out,
    input rst
    );

    //-- divisor register
    reg [23:0] divcounter;
    reg pps_pwm;
    wire overflow;

    assign overflow = (divcounter == counter_value);

    always @(posedge clk_in) begin
        if (overflow | rst == 0) begin
            divcounter <= 0;
        end
        else if (clk_in) begin
            divcounter <= divcounter + 1;
        end
    end

    assign clk_out = (divcounter == 24'h000000);
    assign pps_out = (divcounter < 24'h4C4B40);
endmodule