module fifo #(
    parameter data_width = 8,
    parameter fifo_depth = 32,
    parameter addr_width = $clog2(fifo_depth)) (
    input clk, rst,

    // Write side
    input wr_en,
    input [data_width-1:0] din,
    output full,

    // Read side
    input rd_en,
    output [data_width-1:0] dout,
    output empty,

    output avail,
    output [addr_width:0] count
   );

    localparam ADDR_W=addr_width;
    localparam DATA_W=data_width;
    localparam DEPTH=fifo_depth;

    localparam [ADDR_W-1:0] ADDR_LIMIT=DEPTH-1;
    reg  [ADDR_W-1:0] addr_re=0; // Read pointer
    reg  [ADDR_W-1:0] addr_wr=0; // Write pointer
    reg  [ADDR_W:0]   diff=0;    // [0;DEPTH] => +1
    wire avail_now;
    reg  avail_ff;

    assign count = diff;
    // FIFO RAM
    reg [DATA_W-1:0] ram[DEPTH-1:0];
    reg [ADDR_W-1:0] read_addr_r=0;
    // memory process
    always @(posedge clk) begin
      if (wr_en)
         ram[addr_wr] <= din;
      read_addr_r <= addr_re;
    end
    assign dout=ram[read_addr_r];

    // Use delay for avail_now signal rising edge
    always @(posedge clk)
    begin : avail_ff_proc
       if (~rst)
          avail_ff <= 1'b0;
       else
          avail_ff <= avail_now;
    end // avail_ff_proc
    assign avail_now=diff!=0;
    // Avail signal output
    assign avail=avail_now & avail_ff;

    assign full=diff==DEPTH;
    //assign used=diff;

    always @(posedge clk)
    begin : FIFO_work
      if (~rst)
         begin
         addr_wr <= 0;
         addr_re <= 0;
         diff    <= 0;
         end
      else
         begin
         if (wr_en) // Write to the FIFO.
            begin
            if (addr_wr==ADDR_LIMIT)
               addr_wr <= 0;
            else
               addr_wr <= addr_wr+1;
            diff <= diff+1;
            end
         if (rd_en) // Read to the FIFO.
            begin
            if (addr_re==ADDR_LIMIT)
               addr_re <= 0;
            else
               addr_re <= addr_re+1;
            diff <= diff-1;
            end
         // Concurrent read and write, we increment and decrement, so we
         // let diff unchanged.
         if (rd_en && wr_en)
            diff <= diff;
         end
    end // FIFO_work

    assign empty=~avail_now;
endmodule
