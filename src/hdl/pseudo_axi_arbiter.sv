`default_nettype none

module pseudo_axi_arbiter(
    input   wire        resetn      ,
    input   wire        clk         ,
    output  wire[7:0]   paxi_aid    ,
    output  wire[31:0]  paxi_aaddr  ,
    output  wire[7:0]   paxi_alen   ,
    output  wire[2:0]   paxi_asize  ,
    output  wire[1:0]   paxi_aburst ,
    output  wire[1:0]   paxi_alock  ,
    output  wire        paxi_avalid ,
    input   wire        paxi_aready ,
    output  wire        paxi_atype  ,
    input   wire[7:0]   axi_arid    ,
    input   wire[31:0]  axi_araddr  ,
    input   wire[7:0]   axi_arlen   ,
    input   wire[2:0]   axi_arsize  ,
    input   wire[1:0]   axi_arburst ,
    input   wire[1:0]   axi_arlock  ,
    input   wire        axi_arvalid ,
    output  wire        axi_arready ,
    input   wire[7:0]   axi_awid    ,
    input   wire[31:0]  axi_awaddr  ,
    input   wire[7:0]   axi_awlen   ,
    input   wire[2:0]   axi_awsize  ,
    input   wire[1:0]   axi_awburst ,
    input   wire[1:0]   axi_awlock  ,
    input   wire        axi_awvalid ,
    output  wire        axi_awready
);

endmodule

`default_nettype wire
