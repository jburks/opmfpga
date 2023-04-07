module top(
    input wire rst_n,
    input wire ymclk,
    input wire cs_n,
    input wire wr_n,
    input wire rd_n,
    input wire a0,
    inout wire [7:0] data,
    output wire ct1,
    output wire ct2,
    output wire irq_n,
    output wire i2s_lrck,
    output wire i2s_bck,
    output wire i2s_data,
	output wire [3:0] dbg,
    output wire [7:0] dbg_data,
    output wire mclk
    );

/*module top (
    input           ymclk,
    input           rst_n,
    input           a0,
    input           wr_n,
    input           rd_n,
    input           cs_n,
    inout   [7:0]   data,
    output          irq_n,
    output          ct1,
    output          ct2,

    output          i2s_data,
    output          mclk,
    output          i2s_bck,
    output          i2s_lrclk
);*/

reg     [7:0]   din_b;
reg             a0_b;
reg             wrt_b;
reg             wr_b;
wire    [7:0]   dout;
wire            sample;
wire    [23:0]  left_data;
wire    [23:0]  right_data;
reg             p1;
reg     [5:0]   rst;

wire sh;
wire signed [15:0] ym_left;
wire signed [15:0] ym_right;

assign data = rd_n ? dout : 8'bZ;

HSOSC #(.CLKHF_DIV(2'b01)) OSCInst0 (
    .CLKHFEN(1'b1),
    .CLKHFPU(1'b1),
    .CLKHF(mclk)
);

always @(posedge ymclk, negedge rst_n) begin
    if (!rst_n) begin
        // hold reset pulse to be long enough to clear all BRAM shifters
        p1 <= 0;
        rst <= 6'b111111;
    end else begin
        p1 <= !p1;
        rst <= |rst ? (rst - 6'b1) : 6'b0;
    end
end

// emulate YM2151 asynchronous write timing as jt51 expects a synchronous one
always @(posedge wr_n, negedge rst_n) begin
    if (!rst_n) begin
        din_b <= 0;
        a0_b <= 0;
        wrt_b <= 0;
    end else begin
        din_b <= data;
        a0_b <= a0;
        wrt_b <= !wrt_b;
    end
end

always @(posedge ymclk) begin
    wr_b <= wrt_b;
end

jt51 u_jt51(
    .rst    ( |rst          ),
    .clk    ( ymclk         ),
    .cen    ( 1'b1          ),
    .cen_p1 ( p1            ),
    .cs_n   ( cs_n       ),
    .wr_n   ( wr_b == wrt_b ),
    .a0     ( a0_b          ),
    .din    ( din_b         ),
    .dout   ( dout          ),

    .ct1    ( ct1        ),
    .ct2    ( ct2        ),
    .irq_n  ( irq_n      ),

    .sample (  sh           ),
    .xleft  ( ym_left     ),
    .xright ( ym_right    )
);

    reg signed [23:0] dac_left_r;
    reg signed [23:0] dac_right_r;
    reg signed [15:0] ym_left_r;
    reg signed [15:0] ym_right_r;
    reg signed [15:0] ym_left_r_nxt;
    reg signed [15:0] ym_right_r_nxt;

    always @(*) begin
        ym_left_r_nxt = ym_left_r;
        ym_right_r_nxt = ym_right_r;

        if (sh) begin
            ym_left_r_nxt = ym_left[15:0];
            ym_right_r_nxt = ym_right[15:0];
        end
    end

    always @(posedge ymclk or negedge rst_n) begin
        if (!rst_n) begin
            ym_left_r <= 24'b0;
            ym_right_r <= 24'b0;
        end else begin
            ym_left_r <= ym_left_r_nxt;
            ym_right_r <= ym_right_r_nxt;
        end
    end

    always @(posedge dac_ready or negedge rst_n) begin
        if (!rst_n) begin
            dac_left_r <= 24'b0;
            dac_right_r <= 24'b0;
        end else begin
            dac_left_r <= {ym_left_r[15], ym_left_r[15], ym_left_r[15:0], ym_left_r[15:10]};
            dac_right_r <= {ym_right_r[15], ym_right_r[15], ym_right_r[15:0], ym_right_r[15:10]};
        end
    end

  reg hfclk_div2;
  always @(posedge mclk or negedge rst_n) begin
    if (!rst_n) hfclk_div2 <= 1'b0;
    else hfclk_div2 <= ~hfclk_div2;
  end

  dacif dacif (
    .rst(|rst),
    .clk(hfclk_div2),
    .next_sample(dac_ready),
    .left_data(dac_left_r),
    .right_data(dac_right_r),
    .i2s_lrck(i2s_lrck),
    .i2s_bck(i2s_bck),
    .i2s_data(i2s_data)
    );
endmodule
