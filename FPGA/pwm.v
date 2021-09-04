module pdm #(parameter NBITS = 16)(
    input clk,
    input [NBITS-1:0] PWM_in,
    input [NBITS-1:0] divider,
    output reg PWM_out,
    input pwm_write,
    input pwm_div_write,
    input rst
    );

    reg [NBITS-1:0] pwm_value;
    reg [NBITS-1:0] pwm_divider;

    reg [NBITS-1:0] divided_counter;
    wire divided_clock = divided_counter == 0;

    reg [NBITS-1:0] error;
    reg [NBITS-1:0] error_0;
    reg [NBITS-1:0] error_1;

    always @(posedge clk) begin
      if (pwm_write) pwm_value <= PWM_in;
      if (pwm_div_write) pwm_divider <= divider;
      if (~rst) begin
        error <= 0;
        error_0 <= 0;
        error_1 <= 0;
        divided_counter <= 0;
      end
      else begin          
          if(pwm_divider == divided_counter) begin
              divided_counter <= 0;
          end
          else begin
              divided_counter <= divided_counter + 1;
          end
          if(divided_clock) begin
              error_1 <= error + 2**NBITS - 1 - pwm_value;
              error_0 <= error - pwm_value;
              if (pwm_value >= error) begin
                  PWM_out <= 1;
                  error <= error_1;
              end
              else begin
                  PWM_out <= 0;
                  error <= error_0;
              end
          end
      end
    end
endmodule