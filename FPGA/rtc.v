module RTC(
    input clk,
    input rst,  
    input pps,
    input [5:0] sec_in,min_in,hour_in,
    output [31:0] display_time,
    output [15:0] display_digit,
    output [5:0] sec_out,min_out,hour_out,
    input write_data
    );
    
    reg [5:0] sec,min,hour;

    assign sec_out = sec;
    assign min_out = min;
    assign hour_out = hour;

    wire sec_overflow = (sec == 6'b111011);
    wire min_overflow = (min == 6'b111011) & sec_overflow;
    wire hour_overflow = (hour == 6'b10111) & min_overflow;

    assign display_digit = (sec%2 == 0) ? 16'b0000000000000000 : 16'b00100100_00000000;

    always @(posedge clk) begin
      if (~rst) begin
        sec <= 0;
        min <= 0;
        hour <= 0;
      end
      else begin
        if (write_data) begin
          sec <= sec_in;
          min <= min_in;
          hour <= hour_in;
        end
        else begin
          if (pps) begin
            sec <= sec +1;
            if (sec_overflow) begin
              sec <= 0;
              min <= min +1;
            end
            if (min_overflow) begin
              min <= 0;
              hour <= hour +1;
            end
            if (hour_overflow) begin
              hour <= 0;
            end
          end
        end
      end
    end

    wire [7:0] sec_bcd;
    wire [7:0] min_bcd;
    wire [7:0] hour_bcd;

    bin2bcd sec_conv(sec,sec_bcd);
    bin2bcd min_conv(min,min_bcd);
    bin2bcd hour_conv(hour,hour_bcd);

    // [8] [4] [8] [4] [8]
    //31  23  19  11  7    0
    assign display_time[31:24] = hour_bcd;
    assign display_time[19:12] = min_bcd;
    assign display_time[7:0] = sec_bcd;

    assign display_time[23:20] = 4'b1111;
    assign display_time[11:8] = 4'b1111;
endmodule