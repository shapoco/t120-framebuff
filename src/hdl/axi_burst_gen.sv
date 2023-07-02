`default_nettype none

module axi_burst_gen# (
    parameter int   ADDR_WIDTH  = 32,
    parameter int   STRB_WIDTH  = 32,
    parameter int   ID_WIDTH    = 8,
    parameter int   ID          = 0,
    parameter int   SIZE        = 5,
    parameter int   MAX_BURST_WORDS = 64
) (
    input   wire                clk             ,
    input   wire                rstn            ,
    input   wire[ADDR_WIDTH-1:0]req_addr        ,
    input   wire[ADDR_WIDTH:0]  req_bytes       ,
    input   wire                req_valid       ,
    output  wire                req_ready       ,
    output  wire[8:0]           burst_words     ,
    output  wire                burst_last      ,
    output  wire[STRB_WIDTH-1:0]burst_head_strb ,
    output  wire[STRB_WIDTH-1:0]burst_tail_strb ,
    output  wire                burst_valid     ,
    input   wire                burst_ready     ,
    output  wire[ID_WIDTH-1:0]  axi_axid        ,
    output  wire[ADDR_WIDTH-1:0]axi_axaddr      ,
    output  wire[7:0]           axi_axlen       ,
    output  wire[2:0]           axi_axsize      ,
    output  wire[1:0]           axi_axburst     ,
    output  wire[1:0]           axi_axlock      ,
    output  wire                axi_axvalid     ,
    input   wire                axi_axready 
);

localparam int WORD_SIZE = 1 << SIZE;

typedef enum { 
    RESET, IDLE, BURST_GEN, BURST_WORK
} state_t;

function [8:0] get_burst_words(
    input[ADDR_WIDTH-1:0] addr,
    input[ADDR_WIDTH-SIZE:0] remaining_words
);
    reg[ADDR_WIDTH-1:0] next_4k_boundary;
    reg[ADDR_WIDTH-SIZE:0] burst_words;
    next_4k_boundary = (addr / 4096 + 1) * 4096;
    if (addr + remaining_words * WORD_SIZE > next_4k_boundary) begin
        burst_words = (next_4k_boundary - addr) / WORD_SIZE;
    end else begin
        burst_words = remaining_words;
    end
    return burst_words < MAX_BURST_WORDS ? burst_words : MAX_BURST_WORDS;
endfunction

function [STRB_WIDTH-1:0] get_first_strb(
    input[ADDR_WIDTH-1:0] addr
);
    return ~((1 << (addr % WORD_SIZE)) - 1);
endfunction

function [STRB_WIDTH-1:0] get_final_strb(
    input[ADDR_WIDTH-1:0] addr,
    input[ADDR_WIDTH:0] bytes
);
    reg[7:0] tail_offset;
    tail_offset = (addr + bytes) % WORD_SIZE;
    //return tail_offset != 0 ? (1 << tail_offset) - 1 : (1 << WORD_SIZE) - 1;
    if (tail_offset == 0) begin
        return (1 << WORD_SIZE) - 1;
    end else begin
        reg[STRB_WIDTH-1:0] strb;
        for (int i = 0; i < STRB_WIDTH; i++) begin
            strb[i] = (i < tail_offset);
        end
        return strb;
    end
endfunction

state_t r_state;

assign req_ready = (r_state == IDLE);

logic[ADDR_WIDTH-SIZE:0] r_remaining_words;
logic[ADDR_WIDTH-1:0] r_curr_addr;
logic[8:0] r_burst_words;
logic r_burst_last;
logic[STRB_WIDTH-1:0] r_burst_head_strb;
logic[STRB_WIDTH-1:0] r_burst_tail_strb;
logic[STRB_WIDTH-1:0] r_final_strb;
logic[ADDR_WIDTH-1:0] r_axaddr;
logic[7:0] r_axlen;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_state <= RESET;
        r_remaining_words <= 0;
        r_curr_addr <= 0;
        r_burst_words <= 0;
        r_burst_last <= 0;
        r_burst_head_strb <= 0;
        r_burst_tail_strb <= 0;
        r_final_strb <= 0;
        r_axaddr <= 0;
        r_axlen <= 0;
    end else begin
        case(r_state)
        RESET:
            // 起動
            r_state <= IDLE;

        IDLE:
            // 要求の受理、ワード数や開始アドレス等の計算
            if (req_valid) begin
                r_remaining_words <= ((req_addr % WORD_SIZE) + req_bytes + (WORD_SIZE - 1)) / WORD_SIZE;
                r_curr_addr <= req_addr / WORD_SIZE * WORD_SIZE;
                r_burst_head_strb <= get_first_strb(req_addr);
                r_final_strb <= get_final_strb(req_addr, req_bytes);
                r_state <= BURST_GEN;
            end

        BURST_GEN:
            // バーストの生成
            begin
                reg[8:0] words;
                words = get_burst_words(r_curr_addr, r_remaining_words);
                r_burst_words <= words;
                r_axaddr <= r_curr_addr;
                r_axlen <= words - 1;
                if (r_remaining_words > words) begin
                    r_burst_last <= 0;
                    r_burst_tail_strb <= {WORD_SIZE{1'b1}};
                end else begin
                    r_burst_last <= 1;
                    if (r_remaining_words == 1) begin
                        r_burst_head_strb <= r_burst_head_strb & r_final_strb;
                        r_burst_tail_strb <= r_burst_head_strb & r_final_strb;
                    end else begin
                        r_burst_tail_strb <= r_final_strb;
                    end
                end
                r_state <= BURST_WORK;
            end

        BURST_WORK:
            // バーストの実行
            if (burst_ready && axi_axready) begin
                if (r_remaining_words > r_burst_words) begin
                    r_state <= BURST_GEN;
                end else begin
                    r_state <= IDLE;
                end
                r_remaining_words <= r_remaining_words - r_burst_words;
                r_curr_addr <= r_curr_addr + r_burst_words * WORD_SIZE;
                r_burst_head_strb <= {WORD_SIZE{1'b1}};
            end
        
        default:
            r_state <= RESET;

        endcase
    end
end

assign burst_words      = r_burst_words;
assign burst_last       = r_burst_last;
assign burst_head_strb  = r_burst_head_strb;
assign burst_tail_strb  = r_burst_tail_strb;
assign burst_valid      = (r_state == BURST_WORK) && axi_axready;

assign axi_axaddr   = r_axaddr;
assign axi_axlen    = r_axlen;
assign axi_axid     = ID;
assign axi_axsize   = SIZE;
assign axi_axburst  = 1;
assign axi_axlock   = 0;
assign axi_axvalid  = (r_state == BURST_WORK) && burst_ready;

endmodule

`default_nettype wire
