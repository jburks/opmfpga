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
    output reg [7:0] dbg_data,
    output wire mclk
    );
 /* synthesis RGB_TO_GPIO = "dbg_data[5:3]" */
 
reg     [7:0]   din_b;
reg             a0_b;
reg             wrt_b;  // Write trigger
reg             wr_b;   // Write signal into JT51 core
reg             wrp_b, wrp_b_1, wrp_b_2;  // Write trigger positive pulse match
wire    [7:0]   dout;
wire            sample;
wire    [23:0]  left_data;
wire    [23:0]  right_data;
reg             p1;
reg     [5:0]   rst;

reg [7:0] din_q_2, din_q_1, din_q_0;

wire sh;
wire signed [15:0] ym_left;
wire signed [15:0] ym_right;

reg busy_leader, busy_follower;
wire busy_local = (busy_leader != busy_follower) | dout[7];

assign data = (!rd_n & !cs_n) ? {busy_local,dout[6:0]} : 8'bZ;

reg mclk_r;
assign mclk = mclk_r;
wire hsclk;
always @(posedge hsclk) begin
    mclk_r <= ~mclk_r;
end

HSOSC #(.CLKHF_DIV("0b00")) OSCInst0 (
    .CLKHFEN(1'b1),
    .CLKHFPU(1'b1),
    .CLKHF(hsclk)
);

always @(posedge ymclk, negedge rst_n) begin
    if (!rst_n) begin
        // hold reset pulse to be long enough to clear all BRAM shifters
        p1 <= 0;
        rst <= 6'b111111;
    end else begin
        p1 <= !p1;
        rst <= |rst ? (rst - 6'b1) : 6'b0;
        
		//dbg_data[3] <= p1;
    end
end

// emulate YM2151 asynchronous write timing as jt51 expects a synchronous one
wire write_n = wr_n | cs_n;
always @(posedge write_n, negedge rst_n) begin
    if (!rst_n) begin
        din_b <= 0;
        wrt_b <= 0;
    end else begin
        din_b <= data; //din_q_2; //data;
        wrt_b <= !wrt_b;
    end
end

// data queue from the bus
always @(posedge hsclk) begin
    din_q_2 <= din_q_1;
    din_q_1 <= din_q_0;
    din_q_0 <= write_n ? 8'b0 : data[7:0];
end

always @(negedge write_n, negedge rst_n) begin
    if (!rst_n) begin
        a0_b <= 0;
        busy_leader <= 1'b0;
    end else begin
        a0_b <= a0;
        busy_leader <= ~busy_leader;
    end
end

always @(posedge ymclk) begin
    wr_b <= (wrp_b_2 == wrt_b);
    wrp_b_2 <= wrp_b_1;
    wrp_b_1 <= wrp_b;
    wrp_b <= wrt_b;
end

always @(posedge dout[7], negedge rst_n) begin
    if (!rst_n) busy_follower <= 1'b0;
    else busy_follower <= busy_leader;
end


jt51 u_jt51(
    .rst    ( |rst          ),
    .clk    ( ymclk         ),
    .cen    ( 1'b1          ),
    .cen_p1 ( p1            ),
    .cs_n   ( wr_b          ),
    .wr_n   ( wr_b          ),
    .a0     ( a0_b          ),
    .din    ( din_b       ),
    .dout   ( dout          ),

    .ct1    ( ct1        ),
    .ct2    ( ct2        ),
    .irq_n  ( irq_n      ),

    .sample (  sh           ),
    .xleft  ( ym_left     ),
    .xright ( ym_right    )

//    , .dbg(dbg_w)
//    , .dbg_data(dbg_data_w)
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
