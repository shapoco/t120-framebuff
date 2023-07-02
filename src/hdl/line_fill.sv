`default_nettype none

module line_fill #(
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
    RESET, IDLE, ADDR_CALC_0, ADDR_CALC_1, ADDR_REQ, WAIT_WRITE
} state_t;

logic r_burst_busy;

state_t r_state;
wire w_addr_req_valid;
wire w_addr_req_ready;
logic[AXI_ADDR_WIDTH-1:0] r_addr_req_addr;
logic[AXI_ADDR_WIDTH:0] r_addr_req_bytes;
logic[AXI_ADDR_WIDTH-1:0] r_line_offset;
logic[15:0] r_x;
logic[15:0] r_y;
logic[15:0] r_w;
logic[PIX_WIDTH-1:0] r_color;
assign req_ready = (r_state == IDLE);

// ステートマシン
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_state <= RESET;
        r_addr_req_addr <= 0;
        r_addr_req_bytes <= 0;
        r_line_offset <= 0;
        r_x <= 0;
        r_y <= 0;
        r_w <= 0;
        r_color <= 0;
    end else begin
        case(r_state)
        RESET:
            // 起動
            r_state <= IDLE;

        IDLE:
            // 要求の受理
            if (req_valid) begin
                r_state <= ADDR_CALC_0;
                r_addr_req_addr <= req_base_addr;
                r_x <= req_x;
                r_y <= req_y;
                r_w <= req_w;
                r_color <= req_color;
            end

        ADDR_CALC_0:
            begin
                // アドレス計算1
                r_line_offset <= r_y * STRIDE;
                r_state <= ADDR_CALC_1;
            end

        ADDR_CALC_1:
            begin
                // アドレス計算2
                r_addr_req_addr <= r_addr_req_addr + r_line_offset + r_x * BYTES_PER_PIX;
                r_addr_req_bytes <= r_w * BYTES_PER_PIX;
                r_state <= ADDR_REQ;
            end

        ADDR_REQ:
            // アドレス生成要求の発行
            if (w_addr_req_ready) begin
                r_state <= WAIT_WRITE;
            end

        WAIT_WRITE:
            // 書き込み完了待ち
            if (!r_burst_busy) begin
                r_state <= IDLE;
            end

        default:
            r_state <= RESET;

        endcase
    end
end
assign w_addr_req_valid = (r_state == ADDR_REQ);

wire[8:0] w_burst_words;
wire w_burst_last;
wire[BYTES_PER_WORD-1:0] w_burst_head_strb;
wire[BYTES_PER_WORD-1:0] w_burst_tail_strb;
wire w_burst_valid;
wire w_burst_ready;

// AXI書き込み要求の発行
axi_burst_gen #(
    .ADDR_WIDTH (AXI_ADDR_WIDTH         ),
    .STRB_WIDTH (BYTES_PER_WORD         ),
    .ID_WIDTH   (AXI_ID_WIDTH           ),
    .ID         (AXI_ID                 ),
    .SIZE       ($clog2(BYTES_PER_WORD) )
) u_burst_gen (
    .clk            (clk                ), // input                 
    .rstn           (rstn               ), // input                 
    .req_addr       (r_addr_req_addr    ), // input [ADDR_WIDTH-1:0]
    .req_bytes      (r_addr_req_bytes   ), // input [ADDR_WIDTH-1:0]
    .req_valid      (w_addr_req_valid   ), // input                 
    .req_ready      (w_addr_req_ready   ), // output                 
    .burst_words    (w_burst_words      ), // output[8:0]
    .burst_last     (w_burst_last       ), // output
    .burst_head_strb(w_burst_head_strb  ), // output[STRB_WIDTH-1:0]
    .burst_tail_strb(w_burst_tail_strb  ), // output[STRB_WIDTH-1:0]
    .burst_valid    (w_burst_valid      ), // output     
    .burst_ready    (w_burst_ready      ), // input      
    .axi_axid       (axi_awid           ), // output[ID_WIDTH-1:0]  
    .axi_axaddr     (axi_awaddr         ), // output[ADDR_WIDTH-1:0]
    .axi_axlen      (axi_awlen          ), // output[7:0]           
    .axi_axsize     (axi_awsize         ), // output[2:0]           
    .axi_axburst    (axi_awburst        ), // output[1:0]           
    .axi_axlock     (axi_awlock         ), // output[1:0]           
    .axi_axvalid    (axi_awvalid        ), // output                
    .axi_axready    (axi_awready        )  // input                 
);

assign axi_bready = 1;

wire w_wvalid;
wire w_wready;

logic[8:0] r_burst_words;
logic r_burst_last;
logic[BYTES_PER_WORD-1:0] r_burst_head_strb;
logic[BYTES_PER_WORD-1:0] r_burst_tail_strb;
logic[BYTES_PER_WORD-1:0] r_wstrb;
logic r_wlast;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_burst_busy <= 0;
        r_burst_words <= 0;
        r_burst_last <= 0;
        r_burst_head_strb <= 0;
        r_burst_tail_strb <= 0;
        r_wstrb <= 0;
        r_wlast <= 0;
    end else if (r_state == ADDR_REQ) begin
        r_burst_busy <= 1;
    end else if (r_burst_words > 0) begin
        if (w_wready) begin
            r_burst_words <= r_burst_words - 1;
            if (r_burst_words > 2) begin
                r_wstrb <= {BYTES_PER_WORD{1'b1}};
                r_wlast <= 0;
            end else if (r_burst_words == 2) begin
                r_wstrb <= r_burst_tail_strb;
                r_wlast <= 1;
            end else if (r_burst_words == 1) begin
                if (r_burst_last) begin
                    r_burst_busy <= 0;
                end
            end
        end
    end else if (w_burst_valid) begin
        r_burst_words       <= w_burst_words;
        r_burst_last        <= w_burst_last;
        r_burst_tail_strb   <= w_burst_tail_strb;
        r_wstrb             <= w_burst_head_strb;
        r_wlast             <= (w_burst_words <= 1);
    end
end
assign w_burst_ready = (r_burst_words == 0);

assign w_wvalid = (r_burst_words > 0);

wire[PIX_WIDTH-1:0] w_color;
axi_slice #(
    .DATA_WIDTH(1 + BYTES_PER_WORD + PIX_WIDTH)
) u_slice_wdata (
    .clk        (clk        ), // input                 
    .rstn       (rstn       ), // input                 
    .in_data    ({r_wlast, r_wstrb, r_color}), // input [DATA_WIDTH-1:0]
    .in_valid   (w_wvalid   ), // input                 
    .in_ready   (w_wready   ), // output                
    .out_data   ({axi_wlast, axi_wstrb, w_color}), // output[DATA_WIDTH-1:0]
    .out_valid  (axi_wvalid ), // output                
    .out_ready  (axi_wready )  // input                 
);
assign axi_wdata = {PIXS_PER_WORD{w_color}};
assign axi_wid = AXI_ID;

endmodule

`default_nettype wire
