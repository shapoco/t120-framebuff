`default_nettype none

module cdc_pulse #(
    parameter bit POLARITY  = 0, // 0: active-high, 1: low-active
    parameter bit OUT_REG   = 1
) (
    input   wire    in_clk      ,
    input   wire    in_rstn     ,
    input   wire    in_pulse    ,
    input   wire    out_clk     ,
    input   wire    out_rstn    ,
    output  wire    out_pulse   
);

logic r_toggle;
always_ff @(posedge in_clk) begin
    if (!in_rstn) begin
        r_toggle <= 0;
    end else if (in_pulse != POLARITY) begin
        r_toggle <= ~r_toggle;
    end
end

(* async_reg = "true" *) logic r_toggle_async;
logic r_toggle_sync;
logic r_toggle_dly;
always_ff @(posedge out_clk) begin
    if (!out_rstn) begin
        r_toggle_async <= 0;
        r_toggle_sync <= 0;
        r_toggle_dly <= 0;
    end else begin
        r_toggle_async <= r_toggle;
        r_toggle_sync <= r_toggle_async;
        r_toggle_dly <= r_toggle_sync;
    end
end

wire w_out_pulse = ((r_toggle_dly != r_toggle_sync) ? 1 : 0) ^ POLARITY;

generate
    if (OUT_REG) begin

        logic r_out_pulse;
        always_ff @(posedge out_clk) begin
            if (!out_rstn) begin
                r_out_pulse <= POLARITY;
            end else begin
                r_out_pulse <= w_out_pulse;
            end
        end
        assign out_pulse = r_out_pulse;

    end else begin
        
        assign out_pulse = w_out_pulse;

    end
endgenerate

endmodule

`default_nettype wire
