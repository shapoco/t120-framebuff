`default_nettype none

module rect_draw #(
    parameter int AXI_DATA_WIDTH = 256,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_ID_WIDTH   = 8,
    parameter int AXI_ID         = 0,
    parameter int IMG_WIDTH      = 1920,
    parameter int BYTES_PER_PIX  = 4,
    parameter int PIX_WIDTH      = BYTES_PER_PIX * 8,
    parameter int BYTES_PER_WORD = AXI_DATA_WIDTH / 8,
    parameter int PIXS_PER_WORD  = BYTES_PER_WORD / BYTES_PER_PIX,
    parameter int STRIDE         = IMG_WIDTH * BYTES_PER_PIX
) (
    input   wire                        clk             ,
    input   wire                        rstn            ,

    input   wire[AXI_ADDR_WIDTH-1:0]    req_base_addr   ,
    input   wire[15:0]                  req_x           ,
    input   wire[15:0]                  req_y           ,
    input   wire[15:0]                  req_w           ,
    input   wire[15:0]                  req_h           ,
    input   wire[PIX_WIDTH-1:0]         req_color       ,
    input   wire                        req_valid       ,
    output  wire                        req_ready       ,

    output  wire[AXI_ID_WIDTH-1:0]      axi_awid        ,
    output  wire[AXI_ADDR_WIDTH-1:0]    axi_awaddr      ,
    output  wire[7:0]                   axi_awlen       ,
    output  wire[2:0]                   axi_awsize      ,
    output  wire[1:0]                   axi_awburst     ,
    output  wire[1:0]                   axi_awlock      ,
    output  wire                        axi_awvalid     ,
    input   wire                        axi_awready     ,

    output  wire[AXI_ID_WIDTH-1:0]      axi_wid         ,
    output  wire[AXI_DATA_WIDTH-1:0]    axi_wdata       ,
    output  wire[BYTES_PER_WORD-1:0]    axi_wstrb       ,
    output  wire                        axi_wlast       ,
    output  wire                        axi_wvalid      ,
    input   wire                        axi_wready      ,

    input   wire[AXI_ID_WIDTH-1:0]      axi_bid         ,
    input   wire                        axi_bvalid      ,
    output  wire                        axi_bready
);

typedef enum { 
    RESET, IDLE, TOP, LEFT, RIGHT, BOTTOM
} state_t;

state_t r_state;

wire w_line_req_valid;
wire w_line_req_ready;

logic[AXI_ADDR_WIDTH-1:0] r_req_base_addr;
logic[15:0] r_req_x;
logic[15:0] r_req_y;
logic[15:0] r_req_w;
logic[15:0] r_req_h;
logic[15:0] r_req_right;
logic[15:0] r_req_bottom;
logic[PIX_WIDTH-1:0] r_req_color;
logic[15:0] r_line_req_x;
logic[15:0] r_line_req_y;
logic[15:0] r_line_req_w;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_state <= RESET;
        r_req_base_addr <= 0;
        r_req_x <= 0;
        r_req_y <= 0;
        r_req_w <= 0;
        r_req_h <= 0;
        r_req_right <= 0;
        r_req_bottom <= 0;
        r_req_color <= 0;
        r_line_req_x <= 0;
        r_line_req_y <= 0;
        r_line_req_w <= 0;
    end else begin
        case(r_state)
        RESET:
            r_state <= IDLE;

        IDLE:
            if (req_valid) begin
                r_req_base_addr <= req_base_addr;
                r_req_x <= req_x;
                r_req_y <= req_y;
                r_req_w <= req_w;
                r_req_h <= req_h;
                r_req_right <= req_x + req_w - 1;
                r_req_bottom <= req_y + req_h - 1;
                r_req_color <= req_color;
                r_line_req_x <= req_x;
                r_line_req_y <= req_y;
                r_line_req_w <= req_w;
                r_state <= TOP;
            end

        TOP:
            if (w_line_req_ready) begin
                r_line_req_x <= r_req_x;
                r_line_req_y <= r_req_y;
                r_line_req_w <= 1;
                r_state <= LEFT;
            end

        LEFT:
            if (w_line_req_ready) begin
                if (r_line_req_y < r_req_bottom) begin
                    r_line_req_y <= r_line_req_y + 1;
                end else begin
                    r_line_req_x <= r_req_right;
                    r_line_req_y <= r_req_y;
                    r_line_req_w <= 1;
                    r_state <= RIGHT;
                end
            end

        RIGHT:
            if (w_line_req_ready) begin
                if (r_line_req_y < r_req_bottom) begin
                    r_line_req_y <= r_line_req_y + 1;
                end else begin
                    r_line_req_x <= r_req_x;
                    r_line_req_y <= r_req_bottom;
                    r_line_req_w <= r_req_w;
                    r_state <= BOTTOM;
                end
            end

        BOTTOM:
            if (w_line_req_ready) begin
                r_state <= IDLE;
            end

        endcase
    end
end

assign w_line_req_valid = 
    (r_state == TOP) || 
    (r_state == LEFT) || 
    (r_state == RIGHT) || 
    (r_state == BOTTOM);

line_fill #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH ),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH ),
    .AXI_ID_WIDTH   (AXI_ID_WIDTH   ),
    .AXI_ID         (AXI_ID         ),
    .IMG_WIDTH      (IMG_WIDTH      ),
    .BYTES_PER_PIX  (BYTES_PER_PIX  ),
    .PIX_WIDTH      (PIX_WIDTH      ),
    .BYTES_PER_WORD (BYTES_PER_WORD ),
    .PIXS_PER_WORD  (PIXS_PER_WORD  ),
    .STRIDE         (STRIDE         )
) u_line_fill (
    .clk            (clk                ), // input                         
    .rstn           (rstn               ), // input                         
    .req_base_addr  (r_req_base_addr    ), // input [AXI_ADDR_WIDTH-1:0]    
    .req_x          (r_line_req_x       ), // input [15:0]                  
    .req_y          (r_line_req_y       ), // input [15:0]                  
    .req_w          (r_line_req_w       ), // input [15:0]                  
    .req_color      (r_req_color        ), // input [PIX_WIDTH-1:0]         
    .req_valid      (w_line_req_valid   ), // input                         
    .req_ready      (w_line_req_ready   ), // output                        
    .axi_awid       (axi_awid           ), // output[AXI_ID_WIDTH-1:0]      
    .axi_awaddr     (axi_awaddr         ), // output[AXI_ADDR_WIDTH-1:0]    
    .axi_awlen      (axi_awlen          ), // output[7:0]                   
    .axi_awsize     (axi_awsize         ), // output[2:0]                   
    .axi_awburst    (axi_awburst        ), // output[1:0]                   
    .axi_awlock     (axi_awlock         ), // output[1:0]                   
    .axi_awvalid    (axi_awvalid        ), // output                        
    .axi_awready    (axi_awready        ), // input                         
    .axi_wid        (axi_wid            ), // output[AXI_ID_WIDTH-1:0]      
    .axi_wdata      (axi_wdata          ), // output[AXI_DATA_WIDTH-1:0]    
    .axi_wstrb      (axi_wstrb          ), // output[BYTES_PER_WORD-1:0]    
    .axi_wlast      (axi_wlast          ), // output                        
    .axi_wvalid     (axi_wvalid         ), // output                        
    .axi_wready     (axi_wready         ), // input                         
    .axi_bid        (axi_bid            ), // input [AXI_ID_WIDTH-1:0]      
    .axi_bvalid     (axi_bvalid         ), // input                         
    .axi_bready     (axi_bready         )  // output                        
);

endmodule

`default_nettype wire
