`default_nettype none

module main (
    input CLOCK,
    input CLOCK2,

    //SPI to RPI
    input MOSI,
    input CS,
    input SCK,
    output MISO,

    //RPI GPIO
    output IOB_16,
    output IOB_18,
    input IOB_20,

    //PPS OUT
    output PPS_OUT2,
    output PPS_OUT,

    //TDC7200
    output TDC_CS,
    output TDC_SCLK,
    output TDC_MOSI,
    input  TDC_MISO,
    input  TDC_START,
    output TDC_STOP,
    input  TDC_TRIG,
    output TDC_EN,
    input  TDC_INT,

    //NIXIE Clock
    output NIXIE_CLK,
    output NIXIE_DIN,
    output NIXIE_LE,
    output NIXIE_BL,
    output NIXIE_POL,

    //MAC Lock
    input MAC_LOCK,

    //LEDs
    output pin_ledR,
    output pin_ledG,
    output pin_ledB,

    //ADC
    output ADC_CS,
    output ADC_SCLK,
    output ADC_MOSI,
    input  ADC_MISO,

    //DEBUG
    output IOB_2,
    output IOB_0,
    output IOB_3,
    output IOB_49,
    output IOB_51    
);

  wire CLOCK_BUF;
  SB_GB SB_GB(
    .USER_SIGNAL_TO_GLOBAL_BUFFER(CLOCK),
    .GLOBAL_BUFFER_OUTPUT(CLOCK_BUF)
  );

  wire reset;
  reg [3:0] resetn_counter = 0;
  assign reset = &resetn_counter;

  always @(posedge CLOCK) begin
      if (!reset)
        resetn_counter <= resetn_counter + 1;
  end

  reg [23:0] pps_counterval;
  always @(posedge reset) begin
    pps_counterval<= 24'h98967F;
  end


  wire pps_out;
  wire align_GPS;
  reg align_GPS_startup,align_GPS_startup_next;

  //Capture Rising Pulse from PPS
  wire GPS_PPS = TDC_START;
  reg GPS_PPS_d;
  always @(posedge CLOCK_BUF) begin
      GPS_PPS_d <= GPS_PPS;
  end


  wire rst_ppscounter = ~((GPS_PPS & (~GPS_PPS_d)) & (align_GPS)) & reset;
  wire pps_pulse;
  pulsepersecond fpga_pps(
    .clk_in(CLOCK_BUF),
    .clk_out(pps_pulse),
    .pps_out(pps_out),
    .counter_value(pps_counterval),
    .rst(rst_ppscounter)
  );
  assign PPS_OUT2 = pps_out;
  assign PPS_OUT = pps_out;
  assign IOB_18 = GPS_PPS;

  wire TDC_Read;
  wire TDC_test;
  wire TDC_MOSI_test;
  wire [23:0] TDC_TIME1,TDC_TIME2,TDC_CLOCK_COUNT1,TDC_CALIBRATION1,TDC_CALIBRATION2;
  wire [119:0] TDC_DATA = {TDC_TIME1,TDC_TIME2,TDC_CLOCK_COUNT1,TDC_CALIBRATION1,TDC_CALIBRATION2};
  wire TDC_dataRead;
  TDC7200 tdc(
    .rst(reset),
    .clk(CLOCK_BUF),
    .en(TDC_EN),
    .interrupt(TDC_Read),
    .CS(TDC_CS),
    .SCK(TDC_SCLK),
    .MOSI(TDC_MOSI),
    .MISO(TDC_MISO),
    .debug(TDC_test),
    .TIME1(TDC_TIME1),
    .TIME2(TDC_TIME2),
    .CLOCK_COUNT1(TDC_CLOCK_COUNT1),
    .CALIBRATION1(TDC_CALIBRATION1),
    .CALIBRATION2(TDC_CALIBRATION2),
    .dataRead(TDC_dataRead)
    );

  wire ADC_dataRead,ADC_Debug;
  wire [63:0] ADC_data;
  wire [63:0] adc_timestamp;
  wire [15:0] adc_pps_tag_timestamp;
  wire fifo_full;
  ADC8681 adc(
    .rst(reset),
    .clk(CLOCK_BUF),
    .CS(ADC_CS),
    .SCK(ADC_SCLK),
    .MOSI(ADC_MOSI),
    .MISO(ADC_MISO),
    .debug(ADC_Debug),
    .ADC_data_all(ADC_data),
    .dataRead(ADC_dataRead),
    .timestamp_all(adc_timestamp),
    .fifo_full(fifo_full),
    .pps(pps_pulse),
    .pps_tag_timestamp(adc_pps_tag_timestamp)
    );
 
  wire [31:0] ADC_data_withTimestamp_0 = {ADC_data[15:0],adc_timestamp[15:0]};
  wire [31:0] ADC_data_withTimestamp_1 = {ADC_data[31:16],adc_timestamp[31:16]};
  wire [31:0] ADC_data_withTimestamp_2 = {ADC_data[47:32],adc_timestamp[47:32]};
  wire [31:0] ADC_data_withTimestamp_3 = {ADC_data[63:48],adc_timestamp[63:48]};

  wire [127:0] ADC_data_withTimestamp_all = {ADC_data_withTimestamp_0,ADC_data_withTimestamp_1,ADC_data_withTimestamp_2,ADC_data_withTimestamp_3};

  wire fifo_empty,fifo_avail;
  wire fifo_read,fifo_reset;
  wire [127:0] fifo_data_out;
  wire [10:0] fifo_data_count;
  fifo #(.data_width(128),.fifo_depth(512)) 
  fifo_TX (
      .clk(CLOCK_BUF), 
      .rst((reset==1) & (fifo_reset==0)),

      // Write side => from ADC
      .wr_en(ADC_dataRead),
      .din(ADC_data_withTimestamp_all),
      .full(fifo_full),

      // Read side => SPI read
      .rd_en(fifo_read),
      .dout(fifo_data_out),
      .empty(fifo_empty),

      .avail(fifo_avail),
      .count(fifo_data_count)
  );

  assign IOB_16 = fifo_avail;
  
  wire R,G,B;


  delayPPS delayedPPS(
    .clk(CLOCK_BUF),
    .pps_in(TDC_START),
    .pps_out(TDC_STOP),
    .rst(reset)
  );
  delayPPS delayedPP2(
    .clk(CLOCK_BUF),
    .pps_in(TDC_STOP),
    .pps_out(TDC_Read),
    .rst(reset)
  );




  reg [7:0]  cmd_reg /* synthesis syn_preserve = 1 */;
  reg [7:0] status_reg;
  wire [7:0] mosi_byte;
  reg [7:0] miso_byte;
  wire cmd_byte;
  wire mosi_byte_valid;
  wire miso_byte_req;


  wire read = cmd_reg[7];
  wire write = ~cmd_reg[7];
  wire status_write = mosi_byte_valid && !cmd_byte && write;
  wire [6:0] reg_address = cmd_reg[6:0];


  always @(posedge CLOCK_BUF)begin
      if(~reset)begin
          cmd_reg <= 0;
      end else begin
          if(mosi_byte_valid && cmd_byte)begin
              cmd_reg <= mosi_byte;
          end
      end
  end

  //READ
  reg miso_byte_req_d1;
  reg miso_byte_valid;
  reg [7:0] byte_cnt;

  always @(posedge CLOCK_BUF)begin
      if(~reset)begin
          miso_byte_valid <= 0;
          miso_byte_req_d1 <= 0;
      end else begin
          miso_byte_req_d1 <= miso_byte_req;
          miso_byte_valid <= miso_byte_req_d1;
      end
  end

  always @(posedge CLOCK_BUF)begin
      if(~reset)begin
          miso_byte <= 0;
          byte_cnt <= 0;
          status_reg <= 0;
      end else begin
          if(miso_byte_req_d1)begin
              case(reg_address)
                  0:miso_byte <= gpsCounterByte;
                  1:miso_byte <= tdcDataByte;
                  2:miso_byte <= fifoCount_andTagTimestamp_DataByte;
                  4:miso_byte <= timeDataByte;
                  5: begin
                    miso_byte <= status_reg;
                    status_reg <= 0;
                  end
              endcase
          end
          else begin
            if(fifo_full)begin
                status_reg <= 1;
            end
          end
          if (mosi_byte_valid && ~cmd_byte) begin
              byte_cnt <= byte_cnt + 1;
          end
          else if(mosi_byte_valid && cmd_byte)begin
              byte_cnt <= 0;
          end
      end
  end

  reg [7:0] gpsCounterByte;
  always @ (*) begin
      case(byte_cnt)
          0: gpsCounterByte <= GPS_counter[7:0];
          1: gpsCounterByte <= GPS_counter[15:8];
          2: gpsCounterByte <= GPS_counter[23:16];
          3: gpsCounterByte <= GPS_counter[31:24];
          default:gpsCounterByte <= 0;
      endcase
  end

  reg [7:0] tdcDataByte;
  always @ (*) begin
      case(byte_cnt)
          0: tdcDataByte <= TDC_DATA[7:0];
          1: tdcDataByte <= TDC_DATA[15:8];
          2: tdcDataByte <= TDC_DATA[23:16];
          3: tdcDataByte <= TDC_DATA[31:24];
          4: tdcDataByte <= TDC_DATA[39:32];
          5: tdcDataByte <= TDC_DATA[47:40];
          6: tdcDataByte <= TDC_DATA[55:48];
          7: tdcDataByte <= TDC_DATA[63:56];
          8: tdcDataByte <= TDC_DATA[71:64];
          9: tdcDataByte <= TDC_DATA[79:72];
          10: tdcDataByte <= TDC_DATA[87:80];
          11: tdcDataByte <= TDC_DATA[95:88];
          12: tdcDataByte <= TDC_DATA[103:96];
          13: tdcDataByte <= TDC_DATA[111:104];
          14: tdcDataByte <= TDC_DATA[119:112];
          default:tdcDataByte <= 0;
      endcase
  end

  reg [7:0] fifoCount_andTagTimestamp_DataByte;
  always @ (*) begin
      case(byte_cnt)
          0: fifoCount_andTagTimestamp_DataByte <= fifo_data_count[7:0];
          1: fifoCount_andTagTimestamp_DataByte <= fifo_data_count[10:8];
          2: fifoCount_andTagTimestamp_DataByte <= adc_pps_tag_timestamp[7:0];
          3: fifoCount_andTagTimestamp_DataByte <= adc_pps_tag_timestamp[15:8];
          4: fifoCount_andTagTimestamp_DataByte <= sec_out;
          5: fifoCount_andTagTimestamp_DataByte <= min_out;
          6: fifoCount_andTagTimestamp_DataByte <= hour_out;
          default:fifoCount_andTagTimestamp_DataByte <= 0;
      endcase
  end

  reg [7:0] timeDataByte;
  always @ (*) begin
      case(byte_cnt)
          0: timeDataByte <= sec_out;
          1: timeDataByte <= min_out;
          2: timeDataByte <= hour_out;
          default:timeDataByte <= 0;
      endcase
  end


  //WRITE
  reg [7:0] configReg;
  assign align_GPS = configReg[0];
  wire closeLED = configReg[1];
  wire fifo_reset = configReg[2];
  wire nixieHostControl = configReg[3];
  wire enablePWM = configReg[4];
  wire [1:0]debugMode = configReg[6:5];

  wire config_set = mosi_byte_valid && !cmd_byte && write && (reg_address == 0);
  wire config_clr = mosi_byte_valid && !cmd_byte && write && (reg_address == 14);

  wire second_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 1);
  wire minute_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 2);
  wire hour_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 3);

  wire nixie12_digit_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 4);
  wire nixie34_digit_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 5);
  wire nixie56_digit_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 6);
  wire nixie78_digit_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 7);

  wire nixie1234_dp_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 8);
  wire nixie5678_dp_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 9);

  wire PWM_Low_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 10);
  wire PWM_High_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 11);

  wire PWM_Div_Low_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 12);
  wire PWM_Div_High_write = mosi_byte_valid && !cmd_byte && write && (reg_address == 13);


  reg rtc_write;
  reg [7:0] second;
  reg [7:0] minute;
  reg [7:0] hour;

  reg nixie_write;
  reg [7:0] nixie12_digit;
  reg [7:0] nixie34_digit;
  reg [7:0] nixie56_digit;
  reg [7:0] nixie78_digit;

  reg [7:0] nixie1234_dp;
  reg [7:0] nixie5678_dp;

  reg pwm_write;
  reg [7:0] PWM_Low_reg;
  reg [7:0] PWM_High_reg;

  reg pwm_div_write;
  reg [7:0] PWM_Div_Low_reg;
  reg [7:0] PWM_Div_High_reg;

  always @(posedge CLOCK_BUF)begin
      if(~reset)begin
          configReg <= 0;
      end else begin
          if(fifo_reset) configReg[2] <= 0;
          if(config_set)begin
              configReg <= configReg | mosi_byte;
          end
          if(config_clr)begin
              configReg <= configReg & ~mosi_byte;
          end
          if(second_write)begin
              second <= mosi_byte;
          end
          if(minute_write)begin
              minute <= mosi_byte;
          end
          if(hour_write)begin
              hour <= mosi_byte;
          end

          if(nixie12_digit_write)begin
              nixie12_digit <= mosi_byte;
          end
          if(nixie34_digit_write)begin
              nixie34_digit <= mosi_byte;
          end
          if(nixie56_digit_write)begin
              nixie56_digit <= mosi_byte;
          end
          if(nixie78_digit_write)begin
              nixie78_digit <= mosi_byte;
          end
          if(nixie1234_dp_write)begin
              nixie1234_dp <= mosi_byte;
          end
          if(nixie5678_dp_write)begin
              nixie5678_dp <= mosi_byte;
          end

          if(PWM_Low_write)begin
              PWM_Low_reg <= mosi_byte;
          end
          if(PWM_High_write)begin
              PWM_High_reg <= mosi_byte;
          end
          if(PWM_Div_Low_write)begin
              PWM_Div_Low_reg <= mosi_byte;
          end
          if(PWM_Div_High_write)begin
              PWM_Div_High_reg <= mosi_byte;
          end
          
      end
      if(hour_write | minute_write | second_write) begin
        rtc_write <= 1;
      end
      else begin
        rtc_write <= 0;
      end
      if(nixie78_digit_write | nixie5678_dp_write) begin
        nixie_write <= 1;
      end
      else begin
        nixie_write <= 0;
      end

      if(PWM_High_write) begin
        pwm_write <= 1;
      end
      else begin
        pwm_write <= 0;
      end
      if(PWM_Div_High_write) begin
        pwm_div_write <= 1;
      end
      else begin
        pwm_div_write <= 0;
      end
  end


  wire MISO_CONF;

  spi_slave rpi_spi_dev(
    .i_sys_clk(CLOCK_BUF), //System clock input
    .i_sys_rst(~reset), //Active high reset input

    .miso_byte(miso_byte),
    .miso_byte_valid(miso_byte_valid),
    .miso_byte_req(miso_byte_req),

    .mosi_byte(mosi_byte),
    .mosi_byte_valid(mosi_byte_valid),
    .cmd_byte(cmd_byte),
  
                         //SPI port
    .o_miso(MISO_CONF),
    .i_mosi(MOSI),
    .i_csn(CS),
    .i_sclk(SCK)
  );


  wire MISO_ADC,CS2;
  wire CLKHF;
  oschf osc2(
    .clkhfpu(1'b1),
    .clkhfen(reset),
    .clkhf(CLKHF)
  );

  reg fifo_read_req;
  wire SCK_ADC;

  wire adc_miso_byte_valid,adc_mosi_byte_valid,adc_miso_byte_req;
  wire adc_cmd_byte;

  //CMD
  reg [7:0]  adc_cmd_reg /* synthesis syn_keep = 1 */;
  wire [7:0] adc_mosi_byte;
  reg [7:0] adc_miso_byte;
  always @(posedge CLKHF)begin
      if(~reset)begin
          adc_cmd_reg <= 0;
      end else begin
          if(adc_mosi_byte_valid && adc_cmd_byte)begin
              adc_cmd_reg <= adc_mosi_byte;
          end
      end
  end

  //READ
  reg adc_miso_byte_req_d1;
  reg adc_miso_byte_valid;
  reg [7:0] adc_byte_cnt;

  always @(posedge CLKHF)begin
      if(~reset)begin
          adc_miso_byte_valid <= 0;
          adc_miso_byte_req_d1 <= 0;
      end else begin
          adc_miso_byte_req_d1 <= adc_miso_byte_req;
          adc_miso_byte_valid <= adc_miso_byte_req_d1;
      end
  end

  always @(posedge CLKHF)begin
      if(~reset)begin
          adc_miso_byte <= 0;
          adc_byte_cnt <= 0;
      end else begin
          if(adc_miso_byte_req_d1)begin
              case(adc_cmd_reg)
                  0:adc_miso_byte <= adc_adcDataByte;
                  1:adc_miso_byte <= adc_fifoCount_andTagTimestamp_DataByte;
                  default:adc_miso_byte <= 0;
              endcase
          end
          if (adc_miso_byte_req_d1 && ~adc_cmd_byte) begin
              adc_byte_cnt <= adc_byte_cnt + 1;
          end
          if(adc_mosi_byte_valid && adc_cmd_byte)begin
              adc_byte_cnt <= 0;
          end
          else if (adc_byte_cnt == 8'd16) begin
              fifo_read_req <= 1;
              adc_byte_cnt <= 0;
          end
          else begin
              fifo_read_req <= 0;
          end
      end
  end

  reg [7:0] adc_fifoCount_andTagTimestamp_DataByte;
  always @ (*) begin
      case(adc_byte_cnt)
          0: adc_fifoCount_andTagTimestamp_DataByte <= fifo_data_count[7:0];
          1: adc_fifoCount_andTagTimestamp_DataByte <= fifo_data_count[10:8];
          default:adc_fifoCount_andTagTimestamp_DataByte <= 0;
      endcase
  end

  reg [7:0] adc_adcDataByte;
  always @ (*) begin
      case(adc_byte_cnt)
          0: adc_adcDataByte <= fifo_data_out[7:0];
          1: adc_adcDataByte <= fifo_data_out[15:8];
          2: adc_adcDataByte <= fifo_data_out[23:16];
          3: adc_adcDataByte <= fifo_data_out[31:24];
          4: adc_adcDataByte <= fifo_data_out[39:32];
          5: adc_adcDataByte <= fifo_data_out[47:40];
          6: adc_adcDataByte <= fifo_data_out[55:48];
          7: adc_adcDataByte <= fifo_data_out[63:56];
          8: adc_adcDataByte <= fifo_data_out[71:64];
          9: adc_adcDataByte <= fifo_data_out[79:72];
          10: adc_adcDataByte <= fifo_data_out[87:80];
          11: adc_adcDataByte <= fifo_data_out[95:88];
          12: adc_adcDataByte <= fifo_data_out[103:96];
          13: adc_adcDataByte <= fifo_data_out[111:104];
          14: adc_adcDataByte <= fifo_data_out[119:112];
          15: adc_adcDataByte <= fifo_data_out[127:120];
          default:adc_adcDataByte <= 0;
      endcase
  end


  spi_slave2 rpi_adc_dev(
    .i_sys_clk(CLKHF), //System clock input
    .i_sys_rst(~reset), //Active high reset input

    .miso_byte(adc_miso_byte),
    .miso_byte_valid(adc_miso_byte_valid),
    .miso_byte_req(adc_miso_byte_req),

    .mosi_byte(adc_mosi_byte),
    .mosi_byte_valid(adc_mosi_byte_valid),
    .cmd_byte(adc_cmd_byte),
  
                         //SPI port
    .o_miso(MISO_ADC),
    .i_mosi(MOSI),
    .i_csn(IOB_20),
    .i_sclk(SCK)
  );


  localparam DISABLE_DEBUG = 2'b00;
  localparam PPS_DEBUG = 2'b01;
  localparam SPI_DEBUG = 2'b10;
  localparam ADC_DEBUG = 2'b11;

  reg debug_1,debug_2,debug_3,debug_4,debug_5;
  always @(*) begin
      case(debugMode)
          DISABLE_DEBUG: begin
            debug_1 <= 0;
            debug_2 <= 0;
            debug_3 <= 0;
            debug_4 <= 0;
            debug_5 <= 0;
          end
          PPS_DEBUG: begin
            debug_1 <= GPS_PPS;
            debug_2 <= pps_out;
            debug_3 <= 0;
            debug_4 <= 0;
            debug_5 <= 0;
          end
          SPI_DEBUG: begin
            debug_1 <= MISO_CONF;
            debug_2 <= MOSI;
            debug_3 <= CS;
            debug_4 <= SCK;
            debug_5 <= 0;
          end
          ADC_DEBUG: begin
            debug_1 <= MISO_ADC;
            debug_2 <= MOSI;
            debug_3 <= IOB_20;
            debug_4 <= SCK;
            debug_5 <= 0;
          end
          default: begin
            debug_1 <= 0;
            debug_2 <= 0;
            debug_3 <= 0;
            debug_4 <= 0;
            debug_5 <= 0;
          end
      endcase
  end

  assign IOB_2 = debug_1;
  assign IOB_0 = debug_2;
  assign IOB_3 = debug_3;
  assign IOB_49 = debug_4;
  assign IOB_51 = debug_5;
  
  reg fifo_read_hf,fifo_read_lf_1,fifo_read_lf_2,fifo_read_lf_3;

  always @(posedge CLKHF) begin
      if(fifo_read_req) begin
        fifo_read_hf <= ~fifo_read_hf;
      end
  end
  always @(posedge CLOCK_BUF) begin
      fifo_read_lf_1 <= fifo_read_hf;
      fifo_read_lf_2 <= fifo_read_lf_1;
      fifo_read_lf_3 <= fifo_read_lf_2;
  end
  assign fifo_read = fifo_read_lf_2 ^ fifo_read_lf_3;

  assign MISO = CS ? MISO_ADC : MISO_CONF;


  //GPS_PPS Measurement
  wire [31:0] GPS_counter;
  wire GPS_update;
  CounterModule ppscounter(
      .inputsig(TDC_START),
      .clk(CLOCK_BUF),
      .rst(reset),
      .falling_rising(1'b0),
      .counter(GPS_counter),
      .trigger(GPS_update)
  );

  wire [31:0] RTC_display_digit,RTC_display_digitPoint;
  wire [5:0] sec_out,min_out,hour_out;
  RTC rtc(
    .clk(CLOCK_BUF),
    .rst(reset),
    .pps(pps_pulse),
    .sec_in(second),
    .min_in(minute),
    .hour_in(hour),

    .sec_out(sec_out),
    .min_out(min_out),
    .hour_out(hour_out),

    .display_time(RTC_display_digit),
    .display_digit(RTC_display_digitPoint),
    .write_data(rtc_write)
  );


  wire updateNixie = nixieHostControl? nixie_write : pps_pulse;
  wire [31:0] NixieDigit = nixieHostControl? {nixie12_digit,nixie34_digit,nixie56_digit,nixie78_digit} : RTC_display_digit;
  wire [31:0] NixieDigitPoint = nixieHostControl? {nixie1234_dp,nixie5678_dp} : RTC_display_digitPoint;
  NixieCounter nixie(
    .clk(CLOCK_BUF),
    .rst(reset),
    .NixieBCD(NixieDigit),
    .digitpoint(NixieDigitPoint),
    .NIXIE_LE(NIXIE_LE),
    .NIXIE_CLK(NIXIE_CLK),
    .NIXIE_DIN(NIXIE_DIN),
    .pps(updateNixie),
    .Done()
  );

  wire nixie_pwm;
  pdm pdmdata(
    .clk(CLOCK_BUF),
    .PWM_in({PWM_High_reg,PWM_Low_reg}),
    .divider({PWM_Div_High_reg,PWM_Div_Low_reg}),
    .PWM_out(nixie_pwm),
    .pwm_write(pwm_write),
    .pwm_div_write(pwm_div_write),
    .rst(reset)
  );


  assign NIXIE_BL = enablePWM ? nixie_pwm : 1'b1;

  assign R = ~fifo_full | closeLED;
  assign G = ~GPS_PPS | closeLED;
  assign B = ~TDC_STOP | closeLED;
  SB_IO_OD #(
    .PIN_TYPE(6'b011001),
    .NEG_TRIGGER(1'b0)
  ) pin_out_driverB (
    .PACKAGEPIN(pin_ledB),
    .DOUT0(B)
  );
  SB_IO_OD #(
    .PIN_TYPE(6'b011001),
    .NEG_TRIGGER(1'b0)
  ) pin_out_driverR (
    .PACKAGEPIN(pin_ledR),
    .DOUT0(R)
  );
  SB_IO_OD #(
    .PIN_TYPE(6'b011001),
    .NEG_TRIGGER(1'b0)
  ) pin_out_driverG (
    .PACKAGEPIN(pin_ledG),
    .DOUT0(G)
  );

endmodule


module oschf (
    input clkhfpu,
    input clkhfen,
    output clkhf
);

SB_HFOSC #(
  .CLKHF_DIV("0b00")
) hfosc (
  .CLKHFPU(clkhfpu),
  .CLKHFEN(clkhfen),
  .CLKHF(clkhf)
); 

endmodule