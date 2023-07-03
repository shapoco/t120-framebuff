`default_nettype none

module cdc_2ff #(
    parameter bit POLARITY = 0 // 0: active-high, 1: low-active
) (
    input   wire    in_data     ,
    input   wire    out_clk     ,
    input   wire    out_rstn    ,
    output  wire    out_data
);

(* async_reg = "true" *) logic r_in_data;
logic r_out_data;
always_ff @(posedge out_clk) begin
    if (!out_rstn) begin
        r_in_data <= POLARITY;
        r_out_data <= POLARITY;
    end else begin
        r_in_data <= in_data;
        r_out_data <= r_in_data;
    end
end

assign out_data = r_out_data;

endmodule

`default_nettype wire
