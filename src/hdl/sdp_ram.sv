`default_nettype none

module sdp_ram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int DEPTH      = 1 << ADDR_WIDTH
) (
    input   wire                    wr_clk  ,
    input   wire                    wr_en   ,
    input   wire[ADDR_WIDTH-1:0]    wr_addr ,
    input   wire[DATA_WIDTH-1:0]    wr_data ,
    input   wire                    rd_clk  ,
    input   wire                    rd_en   ,
    input   wire[ADDR_WIDTH-1:0]    rd_addr ,
    output  wire[DATA_WIDTH-1:0]    rd_data
);
    
reg[DATA_WIDTH-1:0] mem [0:DEPTH-1];

always_ff @(posedge wr_clk) begin
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end
end

logic[DATA_WIDTH-1:0] r_rd_data;
always_ff @(posedge rd_clk) begin
    if (rd_en) begin
        r_rd_data <= mem[rd_addr];
    end
end
assign rd_data = r_rd_data;

endmodule

`default_nettype wire
