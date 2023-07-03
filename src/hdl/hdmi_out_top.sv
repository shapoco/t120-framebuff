`default_nettype none

module hdmi_out_top(
    input   wire        aresetn_in      ,
    input   wire        tx_slowclk      ,
    input   wire        video_clk_locked,
    input   wire        ddr_clk_locked  ,
    input   wire        axi_clk         ,

    output  wire[6:0]   lvds_1a_DATA    ,
    output  wire[6:0]   lvds_1b_DATA    ,
    output  wire[6:0]   lvds_1c_DATA    ,
    output  wire[6:0]   lvds_1d_DATA    ,
    output  wire[6:0]   lvds_2a_DATA    ,
    output  wire[6:0]   lvds_2b_DATA    ,
    output  wire[6:0]   lvds_2c_DATA    ,
    output  wire[6:0]   lvds_2d_DATA    ,
    output  wire[6:0]   lvds_clk        ,

	input	wire        it6263_sda_in   ,
	output	wire        it6263_sda_oe   ,
	input	wire        it6263_scl_in   ,
	output	wire        it6263_scl_oe   ,
	output	wire        it6263_xclr     ,
	output	wire        it6263_rstn     ,

	output  wire        ddr0_rstn       ,
	output	wire        ddr0_seq_rst    ,
	output	wire        ddr0_seq_start  ,

    output  wire[7:0]   ddr0_axi0_aid   ,
    output  wire[31:0]  ddr0_axi0_aaddr ,
    output  wire[7:0]   ddr0_axi0_alen  ,
    output  wire[2:0]   ddr0_axi0_asize ,
    output  wire[1:0]   ddr0_axi0_aburst,
    output  wire[1:0]   ddr0_axi0_alock ,
    output  wire        ddr0_axi0_avalid,
    input   wire        ddr0_axi0_aready,
    output  wire        ddr0_axi0_atype ,

    output  wire[7:0]   ddr0_axi0_wid   ,
    output  wire[255:0] ddr0_axi0_wdata ,
    output  wire[31:0]  ddr0_axi0_wstrb ,
    output  wire        ddr0_axi0_wlast ,
    output  wire        ddr0_axi0_wvalid,
    input   wire        ddr0_axi0_wready,

    input   wire[7:0]   ddr0_axi0_rid   ,
    input   wire[255:0] ddr0_axi0_rdata ,
    input   wire        ddr0_axi0_rlast ,
    input   wire        ddr0_axi0_rvalid,
    output  wire        ddr0_axi0_rready,
    input   wire[1:0]   ddr0_axi0_rresp ,

    input   wire[7:0]   ddr0_axi0_bid   ,
    input   wire        ddr0_axi0_bvalid,
    output  wire        ddr0_axi0_bready,
    
    output  wire[7:0]   ddr0_axi1_aid   ,
    output  wire[31:0]  ddr0_axi1_aaddr ,
    output  wire[7:0]   ddr0_axi1_alen  ,
    output  wire[2:0]   ddr0_axi1_asize ,
    output  wire[1:0]   ddr0_axi1_aburst,
    output  wire[1:0]   ddr0_axi1_alock ,
    output  wire        ddr0_axi1_avalid,
    input   wire        ddr0_axi1_aready,
    output  wire        ddr0_axi1_atype ,

    output  wire[7:0]   ddr0_axi1_wid   ,
    output  wire[127:0] ddr0_axi1_wdata ,
    output  wire[15:0]  ddr0_axi1_wstrb ,
    output  wire        ddr0_axi1_wlast ,
    output  wire        ddr0_axi1_wvalid,
    input   wire        ddr0_axi1_wready,

    input   wire[7:0]   ddr0_axi1_rid   ,
    input   wire[127:0] ddr0_axi1_rdata ,
    input   wire        ddr0_axi1_rlast ,
    input   wire        ddr0_axi1_rvalid,
    output  wire        ddr0_axi1_rready,
    input   wire[1:0]   ddr0_axi1_rresp ,

    input   wire[7:0]   ddr0_axi1_bid   ,
    input   wire        ddr0_axi1_bvalid,
    output  wire        ddr0_axi1_bready,
    
    output  wire[7:0]   led
);

wire video_clk = tx_slowclk;

// Reset sync for video clock
wire video_rstn;
reset_sync #(
    .IN_POLARITY (1), // 0: active-high, 1: low-active
    .OUT_POLARITY(1)  // 0: active-high, 1: low-active
) u_reset_video (
    .clk    (video_clk  ), // input 
    .in_rst (aresetn_in ), // input 
    .out_rst(video_rstn )  // output
);

// Reset sync for AXI clock
wire axi_rstn;
reset_sync #(
    .IN_POLARITY (1), // 0: active-high, 1: low-active
    .OUT_POLARITY(1)  // 0: active-high, 1: low-active
) u_reset_axi (
    .clk    (axi_clk    ), // input 
    .in_rst (aresetn_in ), // input 
    .out_rst(axi_rstn   )  // output
);

// DDR reset
ddr_reset_sequencer inst_ddr_reset (
	.ddr_rstn_i         (ddr_clk_locked ),
	.clk                (axi_clk        ),
	.ddr_rstn           (ddr0_rstn      ),
	.ddr_cfg_seq_rst    (ddr0_seq_rst   ),
	.ddr_cfg_seq_start  (ddr0_seq_start )
);

// IT6263 Config
wire w_it6263_confdone;
it6263_config u_it6263_config(
	.i_arst			(~video_rstn        ),
	.i_sysclk		(video_clk          ),
	.i_pll_locked	(video_clk_locked   ),
	.o_state		(/* open */         ),
	.o_confdone		(w_it6263_confdone  ),
	.i_sda			(it6263_sda_in      ),
	.o_sda_oe		(it6263_sda_oe      ),
	.i_scl			(it6263_scl_in      ),
	.o_scl_oe		(it6263_scl_oe      ),
	.o_rstn			(it6263_xclr        )
);
assign it6263_rstn = video_clk_locked;

localparam int RECT_W = 400;
localparam int RECT_H = 400;

wire w_axi_vsync_fall;
logic[15:0] r_x;
logic[15:0] r_y;
logic r_dx;
logic r_dy;
logic[10:0] r_hue;
logic[31:0] r_color;
logic r_rect_draw_req;
always_ff @(posedge axi_clk) begin
    if (!axi_rstn) begin
        r_x <= 100;
        r_y <= 100;
        r_dx <= 1;
        r_dy <= 1;
        r_hue <= 0;
        r_color <= 0;
        r_rect_draw_req <= 0;
    end else if (w_axi_vsync_fall) begin
        if (r_dx) begin
            r_x <= r_x + 1;
            if (r_x >= 1920 - RECT_W - 1) begin
                r_dx <= ~r_dx;
            end
        end else begin
            r_x <= r_x - 1;
            if (r_x <= 1) begin
                r_dx <= ~r_dx;
            end
        end
        if (r_dy) begin
            r_y <= r_y + 1;
            if (r_y >= 1080 - RECT_H - 1) begin
                r_dy <= ~r_dy;
            end
        end else begin
            r_y <= r_y - 1;
            if (r_y <= 1) begin
                r_dy <= ~r_dy;
            end
        end
        if (r_hue < 256 * 6 - 1) begin
            r_hue <= r_hue + 1;
        end else begin
            r_hue <= 0;
        end
        if (r_hue < 256) begin
            r_color[ 7: 0] <= 255;
            r_color[15: 8] <= r_hue;
            r_color[23:16] <= 0;
        end else if (r_hue < 2 * 256) begin
            r_color[ 7: 0] <= 2 * 256 - 1 - r_hue;
            r_color[15: 8] <= 255;
            r_color[23:16] <= 0;
        end else if (r_hue < 3 * 256) begin
            r_color[ 7: 0] <= 0;
            r_color[15: 8] <= 255;
            r_color[23:16] <= r_hue - 2 * 256;
        end else if (r_hue < 4 * 256) begin
            r_color[ 7: 0] <= 0;
            r_color[15: 8] <= 4 * 256 - 1 - r_hue;
            r_color[23:16] <= 255;
        end else if (r_hue < 5 * 256) begin
            r_color[ 7: 0] <= r_hue - 4 * 256;
            r_color[15: 8] <= 0;
            r_color[23:16] <= 255;
        end else begin
            r_color[ 7: 0] <= 255;
            r_color[15: 8] <= 0;
            r_color[23:16] <= 6 * 256 - 1 - r_hue;
        end
        r_rect_draw_req <= 1;
    end else begin
        r_rect_draw_req <= 0;
    end
end

rect_draw #(
//    parameter int AXI_DATA_WIDTH = 256,
//    parameter int AXI_ADDR_WIDTH = 32,
//    parameter int AXI_ID_WIDTH   = 8,
//    parameter int IMG_WIDTH      = 1920,
//    parameter int BYTES_PER_PIX  = 4,
//    parameter int PIX_WIDTH      = BYTES_PER_PIX * 8,
//    parameter int BYTES_PER_WORD = AXI_ADDR_WIDTH / 8,
//    parameter int PIXS_PER_WORD  = BYTES_PER_WORD / BYTES_PER_PIX,
//    parameter int STRIDE         = IMG_WIDTH * BYTES_PER_PIX
) u_rect_draw (
    .clk            (axi_clk            ), // input                         
    .rstn           (axi_rstn           ), // input                         
    .req_base_addr  (0                  ), // input [AXI_ADDR_WIDTH-1:0]    
    .req_x          (r_x                ), // input [15:0]                  
    .req_y          (r_y                ), // input [15:0]                  
    .req_w          (RECT_W             ), // input [15:0]                  
    .req_h          (RECT_H             ), // input [15:0]                  
    .req_color      (r_color            ), // input [PIX_WIDTH-1:0]         
    .req_valid      (r_rect_draw_req    ), // input                         
    .req_ready      (/* open */         ), // output                        
    .axi_awid       (ddr0_axi0_aid      ), // output[AXI_ID_WIDTH-1:0]      
    .axi_awaddr     (ddr0_axi0_aaddr    ), // output[AXI_ADDR_WIDTH-1:0]    
    .axi_awlen      (ddr0_axi0_alen     ), // output[7:0]                   
    .axi_awsize     (ddr0_axi0_asize    ), // output[2:0]                   
    .axi_awburst    (ddr0_axi0_aburst   ), // output[1:0]                   
    .axi_awlock     (ddr0_axi0_alock    ), // output[1:0]                   
    .axi_awvalid    (ddr0_axi0_avalid   ), // output                        
    .axi_awready    (ddr0_axi0_aready   ), // input                         
    .axi_wid        (ddr0_axi0_wid      ), // output[AXI_ID_WIDTH-1:0]      
    .axi_wdata      (ddr0_axi0_wdata    ), // output[AXI_DATA_WIDTH-1:0]    
    .axi_wstrb      (ddr0_axi0_wstrb    ), // output[BYTES_PER_WORD-1:0]    
    .axi_wlast      (ddr0_axi0_wlast    ), // output                        
    .axi_wvalid     (ddr0_axi0_wvalid   ), // output                        
    .axi_wready     (ddr0_axi0_wready   ), // input                         
    .axi_bid        (ddr0_axi0_bid      ), // input [AXI_ID_WIDTH-1:0]      
    .axi_bvalid     (ddr0_axi0_bvalid   ), // input                         
    .axi_bready     (ddr0_axi0_bready   )  // output                        
);
assign ddr0_axi0_atype = 1; // write
assign ddr0_axi0_rready = 1;

wire w_out_vsync;
wire w_out_hsync;
wire w_out_de;
wire[63:0] w_out_data;
video_read_dma u_read_dma(
    .axi_rstn   (axi_rstn           ), // input                         
    .axi_clk    (axi_clk            ), // input                         
    .video_rstn (video_rstn         ), // input                         
    .video_clk  (video_clk          ), // input                         
    .base_addr  (0                  ), // input [AXI_ADDR_WIDTH-1:0]    
    .axi_arid   (ddr0_axi1_aid      ), // output[AXI_ID_WIDTH-1:0]      
    .axi_araddr (ddr0_axi1_aaddr    ), // output[AXI_ADDR_WIDTH-1:0]    
    .axi_arlen  (ddr0_axi1_alen     ), // output[7:0]                   
    .axi_arsize (ddr0_axi1_asize    ), // output[2:0]                   
    .axi_arburst(ddr0_axi1_aburst   ), // output[1:0]                   
    .axi_arlock (ddr0_axi1_alock    ), // output[1:0]                   
    .axi_arvalid(ddr0_axi1_avalid   ), // output                        
    .axi_arready(ddr0_axi1_aready   ), // input                         
    .axi_rid    (ddr0_axi1_rid      ), // input [AXI_ID_WIDTH-1:0]      
    .axi_rdata  (ddr0_axi1_rdata    ), // input [AXI_DATA_WIDTH-1:0]    
    .axi_rlast  (ddr0_axi1_rlast    ), // input                         
    .axi_rvalid (ddr0_axi1_rvalid   ), // input                         
    .axi_rready (ddr0_axi1_rready   ), // output                        
    .axi_rresp  (ddr0_axi1_rresp    ), // input [1:0]                   
    .video_vsync(w_out_vsync        ), // output                        
    .video_hsync(w_out_hsync        ), // output                        
    .video_de   (w_out_de           ), // output                        
    .video_data (w_out_data         )  // output[OUT_WIDTH-1:0]         
);
assign ddr0_axi1_atype = 0; // read
assign ddr0_axi1_wid = 0;
assign ddr0_axi1_wdata = 0;
assign ddr0_axi1_wstrb = 0;
assign ddr0_axi1_wlast = 0;
assign ddr0_axi1_wvalid = 0;
assign ddr0_axi1_bready = 1;

wire w_axi_vsync;
cdc_2ff #(
    .POLARITY(1)
) u_cdc_vsync (
    .in_data    (w_out_vsync), // input   
    .out_clk    (axi_clk    ), // input   
    .out_rstn   (axi_rstn   ), // input   
    .out_data   (w_axi_vsync)  // output  
);

logic[1:0] r_axi_vsync_dly;
always_ff @(posedge axi_clk) begin
    if (!axi_rstn) begin
        r_axi_vsync_dly <= 1;
    end else begin
        r_axi_vsync_dly <= w_axi_vsync;
    end
end
assign w_axi_vsync_fall = r_axi_vsync_dly & ~w_axi_vsync;

wire[1:0][7:0] w_out_r;
wire[1:0][7:0] w_out_g;
wire[1:0][7:0] w_out_b;
assign w_out_r[0] = w_out_data[ 7: 0];
assign w_out_g[0] = w_out_data[15: 8];
assign w_out_b[0] = w_out_data[23:16];
assign w_out_r[1] = w_out_data[39:32];
assign w_out_g[1] = w_out_data[47:40];
assign w_out_b[1] = w_out_data[55:48];
hdmi_out u_hdmi_out(
    .resetn     (video_rstn     ), // input         
    .clk        (video_clk      ), // input         
    .in_vsync   (w_out_vsync    ), // input         
    .in_hsync   (w_out_hsync    ), // input         
    .in_de      (w_out_de       ), // input         
    .in_data_r  (w_out_r        ), // input [15:0]  
    .in_data_g  (w_out_g        ), // input [15:0]  
    .in_data_b  (w_out_b        ), // input [15:0]  
    .out_1b_data(lvds_1b_DATA   ), // output[6:0]   
    .out_1a_data(lvds_1a_DATA   ), // output[6:0]   
    .out_1c_data(lvds_1c_DATA   ), // output[6:0]   
    .out_1d_data(lvds_1d_DATA   ), // output[6:0]   
    .out_2a_data(lvds_2a_DATA   ), // output[6:0]   
    .out_2b_data(lvds_2b_DATA   ), // output[6:0]   
    .out_2c_data(lvds_2c_DATA   ), // output[6:0]   
    .out_2d_data(lvds_2d_DATA   ), // output[6:0]   
    .out_clk    (lvds_clk       )  // output[6:0]   
);

(* async_reg = "true" *) logic[7:0] r_led;
always_ff @(posedge video_clk) begin
    r_led[0] <= video_rstn;
    r_led[1] <= axi_rstn;
    r_led[2] <= video_clk_locked;
    r_led[3] <= ddr_clk_locked;
    r_led[4] <= ~w_out_vsync;
    r_led[5] <= ~w_out_hsync;
    r_led[6] <= w_out_de;
    r_led[7] <= 0;
end
assign led = r_led;

endmodule

`default_nettype wire
