module  spi_slave (
                     //Global signals
    input i_sys_clk, //System clock input
    input i_sys_rst, //Active high reset input

    input [7:0] miso_byte,
    input miso_byte_valid,
    output miso_byte_req,

    output [7:0] mosi_byte,
    output reg mosi_byte_valid,
    output reg cmd_byte,

    //SPI port
    output o_miso,
    input i_mosi,
    input i_csn,
    input i_sclk
    );


    wire                        stb_ack_i;
    reg                         strobe_i;
    reg [7:0]                   address_i;
    reg[7:0]                    tx_data_i;
    wire [7:0]                  rx_data_i;
    reg                         wr_n_i;

    reg [4:0]                   state;
    reg [7:0]                   rx_data_latched_i;
    reg                         csn_int;

    parameter IDLE     = 0;
    parameter STATE_1  = 1;
    parameter STATE_2  = 2;
    parameter STATE_3  = 3;
    parameter STATE_4  = 4;
    parameter STATE_5  = 5;
    parameter STATE_6  = 6;
    parameter STATE_7  = 7;
    parameter STATE_8  = 8;
    parameter STATE_9  = 9;
    parameter STATE_10 = 10;
    parameter STATE_11 = 11;
    parameter STATE_12 = 12;
    parameter STATE_13 = 13;
    parameter STATE_14 = 14;
    parameter STATE_15 = 15;
    parameter STATE_16 = 16;
    parameter SLEEP    = 17;

    parameter BUS_ADDR74 = 8'b0010_0000;


    wire                        terminate_strobe_i;
    wire                        switch_state;
    reg [3:0]                   cycle_count;

    wire                        spi_intr_i;
    wire                        strobe_ack_i;

    wire                        sck_i;
    wire                        sck_oe;
    wire                        i_spi_en;

    wire                        miso_int;
    wire                        miso_oe;


    wire                        csn_falling_i;

    

    //After reset SPI configuration is started
    assign i_spi_en = 1;

    //SPI MISO driver
    assign o_miso = (miso_oe)? miso_int:1'bz;

    reg [2:0]                   sclk_count;
    wire                        byte_read;
    wire                        byte_read_int;
    reg                         byte_read_int_d1;
    reg                         byte_read_int_d2;

    wire                        byte_write;
    wire                        byte_write_int;
    reg                         byte_write_int_d1;
    reg                         byte_write_int_d2;

    
    always @(posedge i_sclk or posedge i_csn)begin
        if(i_csn)begin
            sclk_count <= 0;
        end else begin
            sclk_count <= sclk_count + 1;
        end
    end

    assign byte_read_int = (sclk_count == 7);
    assign byte_write_int = (sclk_count == 3);
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            byte_read_int_d1  <= 0;
            byte_read_int_d2  <= 0;
            byte_write_int_d1 <= 0;
            byte_write_int_d2 <= 0;
        end else begin
            byte_read_int_d1  <= byte_read_int;
            byte_read_int_d2  <= byte_read_int_d1;
            byte_write_int_d1 <= byte_write_int;
            byte_write_int_d2 <= byte_write_int_d1;
        end
    end

    assign byte_write = byte_write_int_d1 && ~byte_write_int_d2;
    assign byte_read  = byte_read_int_d1 && ~byte_read_int_d2;
    
    
    // State machine to drive system interface bus
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            state <= IDLE;
            tx_data_i <= 0;
            address_i <= 0;
            strobe_i <= 0;
            wr_n_i <= 0;
        end else begin
            case(state)
                // Waiting for external trigger to start with configuration sequence                
                IDLE:begin
                    if(i_spi_en)begin 
                        state <= STATE_3;
                    end
                end

                //Write SPI interrupt control register
                STATE_1:begin 
                    if(switch_state)begin
                        state <= STATE_2;
                    end
                    tx_data_i <= 8'b1000_1000;
                    address_i <= 8'b0000_0111;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write SPI control register 0
                STATE_2:begin 
                    if(switch_state)begin
                        state <= STATE_3;
                    end
                    tx_data_i <= 8'b0000_0000;
                    address_i <= 8'b0000_1000;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write SPI control register 1
                STATE_3:begin 
                    if(switch_state)begin
                        state <= STATE_5;
                    end
                    tx_data_i <= 8'b1000_0000;
                    address_i <= 8'b0000_1001;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end
  
                //Write SPI control register 2
                STATE_4:begin 
                    if(switch_state)begin
                        state <= STATE_5;
                    end
                    tx_data_i <= 8'b0000_0000;
                    address_i <= 8'b0000_1010;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Wait for interrupt
                STATE_5:begin 
                    if(csn_falling_i)begin // This is actually sampling falling edge of CSN
                        state <= STATE_12; // Go to read Status 
                    end
                end

                //Read interrupt status register
                STATE_6:begin 
                    if(switch_state)begin
                        state <= STATE_10; //Go to read byte
                    end
                    tx_data_i <= 8'b0010_0100;
                    address_i <= 8'b0000_0110;
                    wr_n_i <= 1'b0;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write interrupt status register
                STATE_7:begin 
                    if(switch_state)begin
                        state <= STATE_8;
                    end
                    tx_data_i <= rx_data_latched_i;
                    address_i <= 8'b0000_0110;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                STATE_8:begin
                    if(miso_byte_valid)begin
                        state <= STATE_9;
                    end
                end
                
                //Write to TXDR 
                STATE_9:begin 
                    if(switch_state)begin
//                        state <= STATE_11; // Read status register 
                        state <= STATE_12; // Read status register 
                    end
                    
                    tx_data_i <= miso_byte;
                    address_i <= 8'b0000_1101;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Read from RXDR 
                STATE_10:begin 
                    if(switch_state)begin
//                        state <= STATE_8; // Wait to write a byte of data
                        state <= STATE_11; // Wait to write a byte of data
                    end
                    tx_data_i <= 8'b1110_0001; //Don't care
                    address_i <= 8'b0000_1110;
                    wr_n_i <= 1'b0; //read
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end
                
                //Read Status register
//                STATE_11:begin 
//                    if(switch_state)begin
//                        state <= STATE_12; // Wait for interrupt
//                    end
//                    tx_data_i <= 8'b1110_0001; //Don't care
//                    address_i <= 8'b0000_1100;
//                    wr_n_i <= 1'b0; //read
//                    
//                    if(terminate_strobe_i)begin
//                        strobe_i <= 1'b0;
//                    end else begin
//                        strobe_i <= 1'b1;
//                    end
//                end
                
                STATE_11:begin 
                    if(byte_write)begin
                        state <= STATE_8;
                    end
                end
                
                STATE_12:begin
                    if(csn_d3)begin
                        state <= STATE_5; // Wait for CSN falling edge
//                    end else if(rx_data_latched_i[3])begin
                    end else if(byte_read)begin
                        state <= STATE_10; // Go to read RXDR
                    end else begin
//                        state <= STATE_11;
                        state <= STATE_12;
                    end
                end
                
                SLEEP:begin //Sleep until reset
                    state <= SLEEP;
                end
            endcase
        end
    end

    // Chip select falling edge detection
    reg csn_d1;
    reg csn_d2;
    reg csn_d3;
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
             csn_d1 <= 1;
             csn_d2 <= 1;
             csn_d3 <= 1;
        end else begin
            csn_d1 <= i_csn;
            csn_d2 <= csn_d1;
            csn_d3 <= csn_d2;
        end
    end

    assign csn_falling_i = ~csn_d2 && csn_d3;

    assign switch_state = (cycle_count == 2);
    assign terminate_strobe_i = (cycle_count > 1);
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            cycle_count <= 0;
        end else begin
            if((state == IDLE) || (state == STATE_5) || 
               (state == STATE_8) || (state == STATE_12) ||
               switch_state) begin
                cycle_count <= 0;
            end else begin
                cycle_count <= cycle_count + 1;
            end
        end
    end

    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            rx_data_latched_i<= 0;
        end else begin
            if((cycle_count == 2)  && (wr_n_i == 0)) begin
                rx_data_latched_i <= rx_data_i;
            end
        end
    end

//    always @(posedge i_sys_clk or posedge i_sys_rst)begin
//        if(i_sys_rst)begin
//            miso_byte_req <= 0;
//        end else begin
//            miso_byte_req <= mosi_byte_valid;
//        end
//    end

    assign miso_byte_req = byte_write;

    assign mosi_byte = rx_data_latched_i;

    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            mosi_byte_valid <= 0;
        end else begin
            if((state == STATE_10) && (cycle_count == 2)) begin
                mosi_byte_valid <= 1;
            end else begin
                mosi_byte_valid <= 0;
            end
        end
    end
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            cmd_byte <= 1;
        end else begin
            if( mosi_byte_valid)begin
                cmd_byte <= 0;
            end else if(csn_d3)begin
                cmd_byte <= 1;
            end
        end
    end

    wire [7:0] address_int;

    // To assign most significant 4 bits of the address line with the parameter BUS_ADDR74
    assign address_int = address_i | BUS_ADDR74;

// Uncomment the definition below to use spi_ip core
//`define SIM  //** This is resolved.. 
    
`ifdef SIM    
   spi_ip DUT (    // This works in simulation, but synthesis tool can not
                   // recognize the core
                .mclk_o(),
                .mclk_oe(),
                .mosi_o(),
                .mosi_oe(),
                .miso_o(miso_int),
                .miso_oe(miso_oe),
                .mcsn_cfg_2d(),
                .mcsn_o(),
                .mcsn_oe(),
                .sb_dat_o(rx_data_i),
                .sb_ack_o(strobe_ack_i),
                .spi_irq(spi_intr_i),
                .spi_wkup(1'b0),
                .SB_ID(4'b0000),
                .spi_rst_async(i_sys_rst),
                .sck_tcv(i_sclk),
                .mosi_i(i_mosi),
                .miso_i(1'b0),
                .scsn_usr(i_csn),
                .sb_clk_i(i_sys_clk),
                .sb_we_i(wr_n_i),
                .sb_stb_i(strobe_i),
                .sb_adr_i(address_int),
                .sb_dat_i(tx_data_i),
                .scan_test_mode(1'b0)
              );
`else
SB_SPI sb_spi_inst( // In simulation this core does not respond to any of the SCI transactions. //** Resolved
                //Inputs
                .SBCLKI            (i_sys_clk),
                .SBRWI             (wr_n_i),
                .SBSTBI            (strobe_i),
                .SBADRI7           (address_int[7]),
                .SBADRI6           (address_int[6]),
                .SBADRI5           (address_int[5]),
                .SBADRI4           (address_int[4]),
                .SBADRI3           (address_int[3]),
                .SBADRI2           (address_int[2]),
                .SBADRI1           (address_int[1]),
                .SBADRI0           (address_int[0]),
                .SBDATI7           (tx_data_i[7]),
                .SBDATI6           (tx_data_i[6]),
                .SBDATI5           (tx_data_i[5]),
                .SBDATI4           (tx_data_i[4]),
                .SBDATI3           (tx_data_i[3]),
                .SBDATI2           (tx_data_i[2]),
                .SBDATI1           (tx_data_i[1]),
                .SBDATI0           (tx_data_i[0]),
                .MI                (1'b0),
                .SI                (i_mosi),
                .SCKI              (i_sclk),
                .SCSNI             (i_csn),
                //Outputs        
                .SBDATO7           (rx_data_i[7]),
                .SBDATO6           (rx_data_i[6]),
                .SBDATO5           (rx_data_i[5]),
                .SBDATO4           (rx_data_i[4]),
                .SBDATO3           (rx_data_i[3]),
                .SBDATO2           (rx_data_i[2]),
                .SBDATO1           (rx_data_i[1]),
                .SBDATO0           (rx_data_i[0]),
                .SBACKO            (strobe_ack_i),
                .SPIIRQ            (spi_intr_i),
                .SO                (miso_int),
                .SOE               (miso_oe),
                .MO                (/*open*/),
                .MOE               (/*open*/),
                .SCKO              (/*open*/),
                .SCKOE             (/*open*/),
                .MCSNO3            (/*open*/),
                .MCSNO2            (/*open*/),
                .MCSNO1            (/*open*/),
                .MCSNO0            (/*open*/),
                .MCSNOE3           (/*open*/),
                .MCSNOE2           (/*open*/),
                .MCSNOE1           (/*open*/),
                .MCSNOE0           (/*open*/)
    );

    defparam sb_spi_inst.BUS_ADDR74 = "0b0010";
    
`endif  

    
endmodule

module  spi_slave2 (
                     //Global signals
    input i_sys_clk, //System clock input
    input i_sys_rst, //Active high reset input

    input [7:0] miso_byte,
    input miso_byte_valid,
    output miso_byte_req,

    output [7:0] mosi_byte,
    output reg mosi_byte_valid,
    output reg cmd_byte,

    //SPI port
    output o_miso,
    input i_mosi,
    input i_csn,
    input i_sclk
    );


    wire                        stb_ack_i;
    reg                         strobe_i;
    reg [7:0]                   address_i;
    reg[7:0]                    tx_data_i;
    wire [7:0]                  rx_data_i;
    reg                         wr_n_i;

    reg [4:0]                   state;
    reg [7:0]                   rx_data_latched_i;
    reg                         csn_int;

    parameter IDLE     = 0;
    parameter STATE_1  = 1;
    parameter STATE_2  = 2;
    parameter STATE_3  = 3;
    parameter STATE_4  = 4;
    parameter STATE_5  = 5;
    parameter STATE_6  = 6;
    parameter STATE_7  = 7;
    parameter STATE_8  = 8;
    parameter STATE_9  = 9;
    parameter STATE_10 = 10;
    parameter STATE_11 = 11;
    parameter STATE_12 = 12;
    parameter STATE_13 = 13;
    parameter STATE_14 = 14;
    parameter STATE_15 = 15;
    parameter STATE_16 = 16;
    parameter SLEEP    = 17;

    parameter BUS_ADDR74 = 8'b0000_0000;


    wire                        terminate_strobe_i;
    wire                        switch_state;
    reg [3:0]                   cycle_count;

    wire                        spi_intr_i;
    wire                        strobe_ack_i;

    wire                        sck_i;
    wire                        sck_oe;
    wire                        i_spi_en;

    wire                        miso_int;
    wire                        miso_oe;


    wire                        csn_falling_i;

    

    //After reset SPI configuration is started
    assign i_spi_en = 1;

    //SPI MISO driver
    assign o_miso = (miso_oe)? miso_int:1'bz;

    reg [2:0]                   sclk_count;
    wire                        byte_read;
    wire                        byte_read_int;
    reg                         byte_read_int_d1;
    reg                         byte_read_int_d2;

    wire                        byte_write;
    wire                        byte_write_int;
    reg                         byte_write_int_d1;
    reg                         byte_write_int_d2;

    
    always @(posedge i_sclk or posedge i_csn)begin
        if(i_csn)begin
            sclk_count <= 0;
        end else begin
            sclk_count <= sclk_count + 1;
        end
    end

    assign byte_read_int = (sclk_count == 7);
    assign byte_write_int = (sclk_count == 3);
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            byte_read_int_d1  <= 0;
            byte_read_int_d2  <= 0;
            byte_write_int_d1 <= 0;
            byte_write_int_d2 <= 0;
        end else begin
            byte_read_int_d1  <= byte_read_int;
            byte_read_int_d2  <= byte_read_int_d1;
            byte_write_int_d1 <= byte_write_int;
            byte_write_int_d2 <= byte_write_int_d1;
        end
    end

    assign byte_write = byte_write_int_d1 && ~byte_write_int_d2;
    assign byte_read  = byte_read_int_d1 && ~byte_read_int_d2;
    
    
    // State machine to drive system interface bus
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            state <= IDLE;
            tx_data_i <= 0;
            address_i <= 0;
            strobe_i <= 0;
            wr_n_i <= 0;
        end else begin
            case(state)
                // Waiting for external trigger to start with configuration sequence                
                IDLE:begin
                    if(i_spi_en)begin 
                        state <= STATE_3;
                    end
                end

                //Write SPI interrupt control register
                STATE_1:begin 
                    if(switch_state)begin
                        state <= STATE_2;
                    end
                    tx_data_i <= 8'b1000_1000;
                    address_i <= 8'b0000_0111;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write SPI control register 0
                STATE_2:begin 
                    if(switch_state)begin
                        state <= STATE_3;
                    end
                    tx_data_i <= 8'b0000_0000;
                    address_i <= 8'b0000_1000;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write SPI control register 1
                STATE_3:begin 
                    if(switch_state)begin
                        state <= STATE_5;
                    end
                    tx_data_i <= 8'b1000_0000;
                    address_i <= 8'b0000_1001;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end
  
                //Write SPI control register 2
                STATE_4:begin 
                    if(switch_state)begin
                        state <= STATE_5;
                    end
                    tx_data_i <= 8'b0000_0000;
                    address_i <= 8'b0000_1010;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Wait for interrupt
                STATE_5:begin 
                    if(csn_falling_i)begin // This is actually sampling falling edge of CSN
                        state <= STATE_12; // Go to read Status 
                    end
                end

                //Read interrupt status register
                STATE_6:begin 
                    if(switch_state)begin
                        state <= STATE_10; //Go to read byte
                    end
                    tx_data_i <= 8'b0010_0100;
                    address_i <= 8'b0000_0110;
                    wr_n_i <= 1'b0;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write interrupt status register
                STATE_7:begin 
                    if(switch_state)begin
                        state <= STATE_8;
                    end
                    tx_data_i <= rx_data_latched_i;
                    address_i <= 8'b0000_0110;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                STATE_8:begin
                    if(miso_byte_valid)begin
                        state <= STATE_9;
                    end
                end
                
                //Write to TXDR 
                STATE_9:begin 
                    if(switch_state)begin
//                        state <= STATE_11; // Read status register 
                        state <= STATE_12; // Read status register 
                    end
                    
                    tx_data_i <= miso_byte;
                    address_i <= 8'b0000_1101;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Read from RXDR 
                STATE_10:begin 
                    if(switch_state)begin
//                        state <= STATE_8; // Wait to write a byte of data
                        state <= STATE_11; // Wait to write a byte of data
                    end
                    tx_data_i <= 8'b1110_0001; //Don't care
                    address_i <= 8'b0000_1110;
                    wr_n_i <= 1'b0; //read
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end
                
                //Read Status register
//                STATE_11:begin 
//                    if(switch_state)begin
//                        state <= STATE_12; // Wait for interrupt
//                    end
//                    tx_data_i <= 8'b1110_0001; //Don't care
//                    address_i <= 8'b0000_1100;
//                    wr_n_i <= 1'b0; //read
//                    
//                    if(terminate_strobe_i)begin
//                        strobe_i <= 1'b0;
//                    end else begin
//                        strobe_i <= 1'b1;
//                    end
//                end
                
                STATE_11:begin 
                    if(byte_write)begin
                        state <= STATE_8;
                    end
                end
                
                STATE_12:begin
                    if(csn_d3)begin
                        state <= STATE_5; // Wait for CSN falling edge
//                    end else if(rx_data_latched_i[3])begin
                    end else if(byte_read)begin
                        state <= STATE_10; // Go to read RXDR
                    end else begin
//                        state <= STATE_11;
                        state <= STATE_12;
                    end
                end
                
                SLEEP:begin //Sleep until reset
                    state <= SLEEP;
                end
            endcase
        end
    end

    // Chip select falling edge detection
    reg csn_d1;
    reg csn_d2;
    reg csn_d3;
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
             csn_d1 <= 1;
             csn_d2 <= 1;
             csn_d3 <= 1;
        end else begin
            csn_d1 <= i_csn;
            csn_d2 <= csn_d1;
            csn_d3 <= csn_d2;
        end
    end

    assign csn_falling_i = ~csn_d2 && csn_d3;

    assign switch_state = (cycle_count == 2);
    assign terminate_strobe_i = (cycle_count > 1);
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            cycle_count <= 0;
        end else begin
            if((state == IDLE) || (state == STATE_5) || 
               (state == STATE_8) || (state == STATE_12) ||
               switch_state) begin
                cycle_count <= 0;
            end else begin
                cycle_count <= cycle_count + 1;
            end
        end
    end

    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            rx_data_latched_i<= 0;
        end else begin
            if((cycle_count == 2)  && (wr_n_i == 0)) begin
                rx_data_latched_i <= rx_data_i;
            end
        end
    end

//    always @(posedge i_sys_clk or posedge i_sys_rst)begin
//        if(i_sys_rst)begin
//            miso_byte_req <= 0;
//        end else begin
//            miso_byte_req <= mosi_byte_valid;
//        end
//    end

    assign miso_byte_req = byte_write;

    assign mosi_byte = rx_data_latched_i;

    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            mosi_byte_valid <= 0;
        end else begin
            if((state == STATE_10) && (cycle_count == 2)) begin
                mosi_byte_valid <= 1;
            end else begin
                mosi_byte_valid <= 0;
            end
        end
    end
    
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            cmd_byte <= 1;
        end else begin
            if( mosi_byte_valid)begin
                cmd_byte <= 0;
            end else if(csn_d3)begin
                cmd_byte <= 1;
            end
        end
    end

    wire [7:0] address_int;

    // To assign most significant 4 bits of the address line with the parameter BUS_ADDR74
    assign address_int = address_i | BUS_ADDR74;

// Uncomment the definition below to use spi_ip core
//`define SIM  //** This is resolved.. 
    
`ifdef SIM    
   spi_ip DUT (    // This works in simulation, but synthesis tool can not
                   // recognize the core
                .mclk_o(),
                .mclk_oe(),
                .mosi_o(),
                .mosi_oe(),
                .miso_o(miso_int),
                .miso_oe(miso_oe),
                .mcsn_cfg_2d(),
                .mcsn_o(),
                .mcsn_oe(),
                .sb_dat_o(rx_data_i),
                .sb_ack_o(strobe_ack_i),
                .spi_irq(spi_intr_i),
                .spi_wkup(1'b0),
                .SB_ID(4'b0000),
                .spi_rst_async(i_sys_rst),
                .sck_tcv(i_sclk),
                .mosi_i(i_mosi),
                .miso_i(1'b0),
                .scsn_usr(i_csn),
                .sb_clk_i(i_sys_clk),
                .sb_we_i(wr_n_i),
                .sb_stb_i(strobe_i),
                .sb_adr_i(address_int),
                .sb_dat_i(tx_data_i),
                .scan_test_mode(1'b0)
              );
`else
SB_SPI sb_spi_inst( // In simulation this core does not respond to any of the SCI transactions. //** Resolved
                //Inputs
                .SBCLKI            (i_sys_clk),
                .SBRWI             (wr_n_i),
                .SBSTBI            (strobe_i),
                .SBADRI7           (address_int[7]),
                .SBADRI6           (address_int[6]),
                .SBADRI5           (address_int[5]),
                .SBADRI4           (address_int[4]),
                .SBADRI3           (address_int[3]),
                .SBADRI2           (address_int[2]),
                .SBADRI1           (address_int[1]),
                .SBADRI0           (address_int[0]),
                .SBDATI7           (tx_data_i[7]),
                .SBDATI6           (tx_data_i[6]),
                .SBDATI5           (tx_data_i[5]),
                .SBDATI4           (tx_data_i[4]),
                .SBDATI3           (tx_data_i[3]),
                .SBDATI2           (tx_data_i[2]),
                .SBDATI1           (tx_data_i[1]),
                .SBDATI0           (tx_data_i[0]),
                .MI                (1'b0),
                .SI                (i_mosi),
                .SCKI              (i_sclk),
                .SCSNI             (i_csn),
                //Outputs        
                .SBDATO7           (rx_data_i[7]),
                .SBDATO6           (rx_data_i[6]),
                .SBDATO5           (rx_data_i[5]),
                .SBDATO4           (rx_data_i[4]),
                .SBDATO3           (rx_data_i[3]),
                .SBDATO2           (rx_data_i[2]),
                .SBDATO1           (rx_data_i[1]),
                .SBDATO0           (rx_data_i[0]),
                .SBACKO            (strobe_ack_i),
                .SPIIRQ            (spi_intr_i),
                .SO                (miso_int),
                .SOE               (miso_oe),
                .MO                (/*open*/),
                .MOE               (/*open*/),
                .SCKO              (/*open*/),
                .SCKOE             (/*open*/),
                .MCSNO3            (/*open*/),
                .MCSNO2            (/*open*/),
                .MCSNO1            (/*open*/),
                .MCSNO0            (/*open*/),
                .MCSNOE3           (/*open*/),
                .MCSNOE2           (/*open*/),
                .MCSNOE1           (/*open*/),
                .MCSNOE0           (/*open*/)
    );

    defparam sb_spi_inst.BUS_ADDR74 = "0b0000";
    
`endif  

    
endmodule
