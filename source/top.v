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

    HSOSC #(.CLKHF_DIV(2'b01)) OSCInst0 (
        .CLKHFEN(1'b1),
        .CLKHFPU(1'b1),
        .CLKHF(mclk)
    );

    wire sh;
    wire signed [15:0] ym_left;
    wire signed [15:0] ym_right;

    wire rst;
    assign rst = !rst_n;

    wire [7:0] data_in;
    wire [7:0] data_out;

    // Handle incoming bus reads
    wire bus_read = !cs_n && !rd_n && wr_n;

    // incoming bus writes
    wire bus_write = !cs_n && !wr_n;
    assign data_in = bus_write ? data : 8'hFF;
    reg m_ym_clk_en;
    reg [2:0] m_wr_q;
    reg [2:0] m_a0_q;
    reg [2:0] m_ymclk_q;
    reg [7:0] m_data_in_0;
    reg [7:0] m_data_in_1;
    reg [7:0] m_data_in_2;

    wire m_wr_negedge = m_wr_q[2:1] == 2'b10;
    wire m_ym_posedge = m_ymclk_q[2:1] == 2'b01;

    reg m_wr, m_wr_next;
    reg m_a0, m_a0_next;
    reg [7:0] m_data_in, m_data_in_next;
    reg m_ym_clk, m_ym_clk_next;
    reg [1:0] m_ym_clk_tgt, m_ym_clk_tgt_next;
    reg [1:0] m_ym_clk_neg_ctr, m_ym_clk_neg_ctr_next;

    always @(*) begin
        m_wr_next = m_wr;
        m_a0_next = m_a0;
        m_data_in_next = m_data_in;
        m_ym_clk_tgt_next = m_ym_clk_tgt;
        if (m_wr_negedge) begin
            m_wr_next = 1'b0;
            m_a0_next = m_a0_q[2];
            m_data_in_next = m_data_in_2;
            m_ym_clk_tgt_next = m_ym_clk_neg_ctr + 1'b1 + m_ym_posedge;
        end else if (m_ym_clk_tgt == m_ym_clk_neg_ctr) begin
            m_wr_next = 1'b1;
        end
        m_ym_clk_next = m_ym_posedge ? 1 : 0;
    end

    always @(posedge mclk or posedge rst) begin
        if (rst) begin
            m_wr <= 1'b0;
            m_a0 <= 1'b0;
            m_data_in <= 8'b0;
            m_ym_clk <= 1'b0;
            m_ym_clk_tgt <= 2'b00;
        end else begin
            m_wr <= m_wr_next;
            m_a0 <= m_a0_next;
            m_data_in <= m_data_in_next;
            m_ym_clk <= m_ym_clk_next;
            m_ym_clk_tgt <= m_ym_clk_tgt_next;
        end
    end

    always @(posedge mclk or posedge rst) begin
        if (rst) begin
            m_wr_q[2:0] <= 3'b0;
            m_a0_q[2:0] <= 3'b0;
            m_ymclk_q[2:0] <= 3'b0;
            m_data_in_0 <= 8'b0;
            m_data_in_1 <= 8'b0;
            m_data_in_2 <= 8'b0;
        end else begin
            m_wr_q[2:0] <= {m_wr_q[1:0], bus_write};
            m_a0_q[2:0] <= {m_a0_q[1:0], a0};
            m_ymclk_q[2:0] <= {m_ymclk_q[1:0], ymclk};
            m_data_in_0 <= data_in;
            m_data_in_1 <= m_data_in_0;
            m_data_in_2 <= m_data_in_1;
        end
    end

    wire busy = data_out[7];

    assign data = bus_read ? { busy, data_out[6:0] } : 8'bZ;
    // generate half speed clock enable
    // drive ym_clk_en on negedge ymclk to ensure that ym_clk_en is always high before posedge ymclk
    always @(*) begin
        m_ym_clk_neg_ctr_next = m_ym_clk_neg_ctr + 1'b1;
    end
    always @(negedge m_ym_clk or posedge rst) begin
        if(rst) begin
            m_ym_clk_en <= 1'b0;
            m_ym_clk_neg_ctr <= 2'b0;
        end else begin
            m_ym_clk_en <= ~m_ym_clk_en;
            m_ym_clk_neg_ctr <= m_ym_clk_neg_ctr_next;
        end
    end

    assign dbg_data[7:0] = {m_wr_negedge, m_ym_posedge, m_ym_clk_tgt[1:0], m_ym_clk_neg_ctr[1:0], mclk, m_ym_clk}; //{m_wr_negedge, busy, 3'b0, 1'b0, 1'b0, m_wr};
    assign dbg[2:0] = {m_a0, m_wr, busy};

  jt51 YM2151 (
    .rst(rst),
    .clk(m_ym_clk),
    .cen(1'b1),
    .cen_p1(m_ym_clk_en),
    .cs_n(m_wr), // .cs_n(cs_n),
    .wr_n(m_wr),
    .a0(m_a0),
    .din(m_data_in),//	.din(data),
    .dout(data_out),
    .ct1(ct1),
    .ct2(ct2),
    .irq_n(irq_n),
    .sample(sh),
    .xleft(ym_left),
    .xright(ym_right)
//    , .dbg(dbg)
//    , .dbg_data(dbg_data)
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

    always @(posedge ymclk or posedge rst) begin
        if (rst) begin
            ym_left_r <= 24'b0;
            ym_right_r <= 24'b0;
        end else begin
            ym_left_r <= ym_left_r_nxt;
            ym_right_r <= ym_right_r_nxt;
        end
    end

    always @(posedge dac_ready or posedge rst) begin
        if (rst) begin
            dac_left_r <= 24'b0;
            dac_right_r <= 24'b0;
        end else begin
            dac_left_r <= {ym_left_r[15], ym_left_r[15], ym_left_r[15:0], ym_left_r[15:10]};
            dac_right_r <= {ym_right_r[15], ym_right_r[15], ym_right_r[15:0], ym_right_r[15:10]};
        end
    end

  reg hfclk_div2;
  always @(posedge mclk or posedge rst) begin
    if (rst) hfclk_div2 <= 1'b0;
    else hfclk_div2 <= ~hfclk_div2;
  end

  dacif dacif (
    .rst(rst),
    .clk(hfclk_div2),
    .next_sample(dac_ready),
    .left_data(dac_left_r),
    .right_data(dac_right_r),
    .i2s_lrck(i2s_lrck),
    .i2s_bck(i2s_bck),
    .i2s_data(i2s_data)
    );
endmodule