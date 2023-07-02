`default_nettype none

module video_sync_gen #(
    parameter int VPERIOD       = 1125  ,
    parameter int HPERIOD       = 1100  ,
    parameter int VSYNC_LINES   = 5     ,
    parameter int HSYNC_WIDTH   = 22    ,
    parameter int VALID_YSTART  = 30    ,
    parameter int VALID_LINES   = 1080  ,
    parameter int VALID_XSTART  = 96    ,
    parameter int VALID_WIDTH   = 960
) (
    input   wire    rstn    ,
    input   wire    clk     ,
    output  wire    dma_req ,
    output  wire    vsync   ,
    output  wire    hsync   ,
    output  wire    de
);

localparam int VALID_YEND = VALID_YSTART + VALID_LINES;
localparam int VALID_XEND = VALID_XSTART + VALID_WIDTH;

// ライン/ピクセルカウンタ
logic[$clog2(VPERIOD)-1:0] r_y_cntr;
logic[$clog2(HPERIOD)-1:0] r_x_cntr;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_x_cntr <= 0;
        r_y_cntr <= 0;
    end else if (r_x_cntr < HPERIOD - 1) begin
        r_x_cntr <= r_x_cntr + 1;
    end else if (r_y_cntr < VPERIOD - 1) begin
        r_x_cntr <= 0;
        r_y_cntr <= r_y_cntr + 1;
    end else begin
        r_x_cntr <= 0;
        r_y_cntr <= 0;
    end
end

// DMAリクエストタイミングの生成
wire[15:0] w_dma_y = r_y_cntr + 1;
wire w_dma_req = (VALID_YSTART <= w_dma_y) && (w_dma_y < VALID_YEND) && (r_x_cntr == VALID_XEND);
logic r_dma_req;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_dma_req  <= 0;
    end else begin
        r_dma_req  <= w_dma_req;
    end
end
assign dma_req = r_dma_req;

// VSYNC/HSYNC/DEの生成
wire w_vsync = (r_y_cntr < VSYNC_LINES) ? 0 : 1;
wire w_hsync = (r_x_cntr < HSYNC_WIDTH) ? 0 : 1;
wire w_vde = (VALID_YSTART <= r_y_cntr && r_y_cntr < VALID_YEND) ? 1 : 0;
wire w_hde = (VALID_XSTART <= r_x_cntr && r_x_cntr < VALID_XEND) ? 1 : 0;
logic r_hsync, r_vsync, r_de;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_vsync <= 1;
        r_hsync <= 1;
        r_de    <= 0;
    end else begin
        r_hsync <= w_hsync;
        r_vsync <= w_vsync;
        r_de    <= w_vde & w_hde;
    end
end
assign vsync = r_vsync;
assign hsync = r_hsync;
assign de    = r_de;

endmodule

`default_nettype wire
