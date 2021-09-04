module CounterModule(
    input inputsig,
    input clk,
    input rst,
    input falling_rising,
    output reg [31:0] counter,
    output trigger
    );

    reg [1:0] FallingPulse;
    reg inputSig_d;

    reg [31:0] internalCounter;

    assign trigger = falling_rising? (FallingPulse==2'b10) : (FallingPulse==2'b01);

    always @(posedge clk) begin
        inputSig_d <= inputsig;
        FallingPulse <= {FallingPulse[0],inputSig_d};
        if (~rst) begin
            internalCounter <= 0;
            counter <= 0;
        end
        else begin
            if (trigger) begin
                internalCounter <= 1;
                counter <= internalCounter;
            end
            else begin
                internalCounter <= internalCounter + 1;
            end
        end
    end
endmodule
