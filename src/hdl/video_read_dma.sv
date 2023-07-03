`default_nettype none

module video_read_dma #(
    parameter int AXI_ADDR_WIDTH = 32   ,
    parameter int AXI_DATA_WIDTH = 128  ,
    parameter int AXI_ID_WIDTH   = 8    ,
    parameter int AXI_ID         = 0    ,
    parameter int BYTES_PER_PIX  = 4    ,
    parameter int IMG_WIDTH      = 1920 ,
    parameter int PIXS_PER_CYC   = 2    ,
    parameter int OUT_WIDTH      = BYTES_PER_PIX * PIXS_PER_CYC * 8,
    parameter int STRIDE         = BYTES_PER_PIX * IMG_WIDTH
) (
    input   wire                        axi_rstn    ,
    input   wire                        axi_clk     ,
    input   wire                        video_rstn  ,
    input   wire                        video_clk   ,

    input   wire[AXI_ADDR_WIDTH-1:0]    base_addr   ,

    output  wire[AXI_ID_WIDTH-1:0]      axi_arid    ,
    output  wire[AXI_ADDR_WIDTH-1:0]    axi_araddr  ,
    output  wire[7:0]                   axi_arlen   ,
    output  wire[2:0]                   axi_arsize  ,
    output  wire[1:0]                   axi_arburst ,
    output  wire[1:0]                   axi_arlock  ,
    output  wire                        axi_arvalid ,
    input   wire                        axi_arready ,
    input   wire[AXI_ID_WIDTH-1:0]      axi_rid     ,
    input   wire[AXI_DATA_WIDTH-1:0]    axi_rdata   ,
    input   wire                        axi_rlast   ,
    input   wire                        axi_rvalid  ,
    output  wire                        axi_rready  ,
    input   wire[1:0]                   axi_rresp   ,

    output  wire                        video_vsync ,
    output  wire                        video_hsync ,
    output  wire                        video_de    ,
    output  wire[OUT_WIDTH-1:0]         video_data
);

localparam int BYTES_PER_WORD = AXI_DATA_WIDTH / 8;
localparam int BYTES_PER_LINE = IMG_WIDTH * BYTES_PER_PIX;
localparam int WORDS_PER_LINE = BYTES_PER_LINE / BYTES_PER_WORD;
localparam int RAM_ADDR_WIDTH = $clog2(WORDS_PER_LINE);

wire w_vid_dma_req;
wire w_vid_vsync;
wire w_vid_hsync;
wire w_vid_de;
video_sync_gen u_sync_gen (
    .rstn   (video_rstn     ), // input
    .clk    (video_clk      ), // input
    .dma_req(w_vid_dma_req  ), // output
    .vsync  (w_vid_vsync    ), // output 
    .hsync  (w_vid_hsync    ), // output 
    .de     (w_vid_de       )  // output 
);

// 読み出しリクエスト載せ替え
wire w_axi_dma_req;
cdc_pulse u_cdc_dma_req (
    .in_clk     (video_clk      ), // input 
    .in_rstn    (video_rstn     ), // input 
    .in_pulse   (w_vid_dma_req  ), // input 
    .out_clk    (axi_clk        ), // input 
    .out_rstn   (axi_rstn       ), // input 
    .out_pulse  (w_axi_dma_req  )  // output
);

// VSYNC載せ替え
wire w_axi_vsync;
cdc_2ff #(
    .POLARITY(1)
) u_cdc_vsync (
    .in_data    (w_vid_vsync), // input   
    .out_clk    (axi_clk    ), // input   
    .out_rstn   (axi_rstn   ), // input   
    .out_data   (w_axi_vsync)  // output  
);

// AXI読み出しアドレスの生成
logic[AXI_ADDR_WIDTH-1:0] r_axi_dma_addr;
always_ff @(posedge axi_clk) begin
    if (!axi_rstn) begin
        r_axi_dma_addr <= 0;
    end else if (!w_axi_vsync) begin
        r_axi_dma_addr <= base_addr;
    end else if (w_axi_dma_req) begin
        r_axi_dma_addr <= r_axi_dma_addr + STRIDE;
    end
end

// AXI読み出し要求の発行
axi_burst_gen #(
    .ADDR_WIDTH (AXI_ADDR_WIDTH         ),
    .STRB_WIDTH (BYTES_PER_WORD         ),
    .ID_WIDTH   (AXI_ID_WIDTH           ),
    .ID         (AXI_ID                 ),
    .SIZE       ($clog2(BYTES_PER_WORD) )
) u_burst_gen (
    .clk            (axi_clk        ), // input                 
    .rstn           (axi_rstn       ), // input                 
    .req_addr       (r_axi_dma_addr ), // input [ADDR_WIDTH-1:0]
    .req_bytes      (BYTES_PER_LINE ), // input [ADDR_WIDTH:0]
    .req_valid      (w_axi_dma_req  ), // input                 
    .req_ready      (/* open */     ), // output          
    .burst_words    (/* open */     ), // output[8:0]
    .burst_last     (/* open */     ), // output
    .burst_head_strb(/* open */     ), // output[STRB_WIDTH-1:0]
    .burst_tail_strb(/* open */     ), // output[STRB_WIDTH-1:0]
    .burst_valid    (/* open */     ), // output     
    .burst_ready    (1              ), // input      
    .axi_axid       (axi_arid       ), // output[ID_WIDTH-1:0]  
    .axi_axaddr     (axi_araddr     ), // output[ADDR_WIDTH-1:0]
    .axi_axlen      (axi_arlen      ), // output[7:0]           
    .axi_axsize     (axi_arsize     ), // output[2:0]           
    .axi_axburst    (axi_arburst    ), // output[1:0]           
    .axi_axlock     (axi_arlock     ), // output[1:0]           
    .axi_axvalid    (axi_arvalid    ), // output                
    .axi_axready    (axi_arready    )  // input                 
);

assign axi_rready = 1;

// ラインバッファ書き込みアドレスアドレス生成
logic[RAM_ADDR_WIDTH-1:0] r_axi_ram_wr_addr;
always_ff @(posedge axi_clk) begin
    if (!axi_rstn) begin
        r_axi_ram_wr_addr <= 0;
    end else if (w_axi_dma_req) begin
        r_axi_ram_wr_addr <= 0;
    end else if (axi_rvalid) begin
        r_axi_ram_wr_addr <= r_axi_ram_wr_addr + 1;
    end
end

// ラインバッファ
logic r_vid_ram_rd_en;
logic[RAM_ADDR_WIDTH-1:0] r_vid_ram_rd_addr;
wire[AXI_DATA_WIDTH-1:0] w_vid_ram_rd_data;
sdp_ram #(
    .DATA_WIDTH (AXI_DATA_WIDTH ),
    .ADDR_WIDTH (RAM_ADDR_WIDTH ),
    .DEPTH      (WORDS_PER_LINE )
) lbuf_0 (
    .wr_clk (axi_clk            ), // input                     
    .wr_en  (axi_rvalid         ), // input                     
    .wr_addr(r_axi_ram_wr_addr  ), // input [ADDR_WIDTH-1:0]    
    .wr_data(axi_rdata          ), // input [DATA_WIDTH-1:0]    
    .rd_clk (video_clk          ), // input                     
    .rd_en  (1                  ), // input                     
    .rd_addr(r_vid_ram_rd_addr  ), // input [ADDR_WIDTH-1:0]    
    .rd_data(w_vid_ram_rd_data  )  // output[DATA_WIDTH-1:0]    
);

// ラインバッファ読み出し制御
logic[7:0] r_vid_byte_cntr;
always_ff @(posedge video_clk) begin
    if (!video_rstn) begin
        r_vid_byte_cntr <= 0;
        r_vid_ram_rd_en <= 0;
        r_vid_ram_rd_addr <= 0;
    end else if (!w_vid_hsync) begin
        r_vid_byte_cntr <= 0;
        r_vid_ram_rd_en <= 0;
        r_vid_ram_rd_addr <= 0;
    end else if (w_vid_de) begin
        r_vid_ram_rd_en <= (r_vid_byte_cntr == 0);
        if (r_vid_byte_cntr < BYTES_PER_WORD - BYTES_PER_PIX * PIXS_PER_CYC) begin
            r_vid_byte_cntr <= r_vid_byte_cntr + BYTES_PER_PIX * PIXS_PER_CYC;
        end else begin
            r_vid_byte_cntr <= 0;
            r_vid_ram_rd_addr <= r_vid_ram_rd_addr + 1;
        end
    end else begin
        r_vid_ram_rd_en <= 0;
    end
end

// ピクセルデータの押し出し
logic r_vid_rd_en_dly;
logic[AXI_DATA_WIDTH-1:0] r_vid_data_sreg;
always_ff @(posedge video_clk) begin
    if (!video_rstn) begin
        r_vid_rd_en_dly <= 0;
        r_vid_data_sreg <= 0;
    end else begin
        r_vid_rd_en_dly <= r_vid_ram_rd_en;
        if (r_vid_rd_en_dly) begin
            r_vid_data_sreg <= w_vid_ram_rd_data;
        end else begin
            r_vid_data_sreg <= r_vid_data_sreg >> OUT_WIDTH;
        end
    end
end
assign video_data = r_vid_data_sreg[OUT_WIDTH-1:0];

// 同期信号タイミング調整
delay_reg #(
    .DEPTH  (3      ),
    .WIDTH  (3      ),
    .INIT   (3'b110 )
) u_sync_delay (
    .clk    (video_clk      ),
    .rstn   (video_rstn     ),
    .clken  (1              ),
    .in     ({w_vid_vsync, w_vid_hsync, w_vid_de}),
    .out    ({video_vsync, video_hsync, video_de})
);

endmodule

`default_nettype wire
