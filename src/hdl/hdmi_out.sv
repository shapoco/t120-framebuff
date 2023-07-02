`default_nettype none

module hdmi_out(
    input   wire        resetn      ,
    input   wire        clk         ,
    
    input   wire        in_vsync    ,
    input   wire        in_hsync    ,
    input   wire        in_de       ,
    input   wire[15:0]  in_data_r   ,
    input   wire[15:0]  in_data_g   ,
    input   wire[15:0]  in_data_b   ,

    output  wire[6:0]   out_1a_data ,
    output  wire[6:0]   out_1b_data ,
    output  wire[6:0]   out_1c_data ,
    output  wire[6:0]   out_1d_data ,
    output  wire[6:0]   out_2a_data ,
    output  wire[6:0]   out_2b_data ,
    output  wire[6:0]   out_2c_data ,
    output  wire[6:0]   out_2d_data ,
    output  wire[6:0]   out_clk
);

wire[7:0] w_r1 = in_de ? in_data_r[7:0] : 0;
wire[7:0] w_g1 = in_de ? in_data_g[7:0] : 0;
wire[7:0] w_b1 = in_de ? in_data_b[7:0] : 0;
wire[7:0] w_r2 = in_de ? in_data_r[15:8] : 0;
wire[7:0] w_g2 = in_de ? in_data_g[15:8] : 0;
wire[7:0] w_b2 = in_de ? in_data_b[15:8] : 0;

logic[6:0] r_1a_data;
logic[6:0] r_1b_data;
logic[6:0] r_1c_data;
logic[6:0] r_1d_data;
logic[6:0] r_2a_data;
logic[6:0] r_2b_data;
logic[6:0] r_2c_data;
logic[6:0] r_2d_data;
always_ff @(posedge clk) begin
    if (!resetn) begin
        r_1a_data <= 0;
        r_1b_data <= 0;
        r_1c_data <= 0;
        r_1d_data <= 0;
        r_2a_data <= 0;
        r_2b_data <= 0;
        r_2c_data <= 0;
        r_2d_data <= 0;
    end else begin
        r_1a_data <= {w_r1[0], w_r1[1], w_r1[2], w_r1[3], w_r1[4], w_r1[5], w_g1[0]};
        r_1b_data <= {w_g1[1], w_g1[2], w_g1[3], w_g1[4], w_g1[5], w_b1[0], w_b1[1]};
        r_1c_data <= {w_b1[2], w_b1[3], w_b1[4], w_b1[5], in_hsync, in_vsync, in_de};
        r_1d_data <= {w_r1[6], w_r1[7], w_g1[6], w_g1[7], w_b1[6], w_b1[7], 1'b0};
        r_2a_data <= {w_r2[0], w_r2[1], w_r2[2], w_r2[3], w_r2[4], w_r2[5], w_g2[0]};
        r_2b_data <= {w_g2[1], w_g2[2], w_g2[3], w_g2[4], w_g2[5], w_b2[0], w_b2[1]};
        r_2c_data <= {w_b2[2], w_b2[3], w_b2[4], w_b2[5], in_hsync, in_vsync, in_de};
        r_2d_data <= {w_r2[6], w_r2[7], w_g2[6], w_g2[7], w_b2[6], w_b2[7], 1'b0};
    end
end

assign out_1a_data = r_1a_data;
assign out_1b_data = r_1b_data;
assign out_1c_data = r_1c_data;
assign out_1d_data = r_1d_data;
assign out_2a_data = r_2a_data;
assign out_2b_data = r_2b_data;
assign out_2c_data = r_2c_data;
assign out_2d_data = r_2d_data;
assign out_clk = 7'b1100011;

endmodule

`default_nettype wire
