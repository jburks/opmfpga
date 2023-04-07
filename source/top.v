module top(
    input wire rst_n,
    input wire clk,
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
//    output wire led_red  , // Red
//    output wire led_blue , // Blue
//    output wire led_green,  // Green
    output wire [3:0] dbg,
    output wire [7:0] dbg_data,
    output wire mclk
    );

    wire hfclk;

    HSOSC #(.CLKHF_DIV("0b01")) OSCInst0 (
        .CLKHFEN(1'b1),
        .CLKHFPU(1'b1),
        .CLKHF(hfclk)
    );

    assign mclk = hfclk;

	reg [27:0] frequency_counter_i;
	always @(posedge clk) begin
		frequency_counter_i = frequency_counter_i + 1'b1;
	end

	wire sh;
	wire signed [15:0] ym_left;
	wire signed [15:0] ym_right;
/*
  RGB RGB_DRIVER (
    .RGBLEDEN(1'b1                                            ),
    .RGB0PWM (ym_left[15]&frequency_counter_i[12]&frequency_counter_i[11]),
    .RGB1PWM (ym_right[15]&frequency_counter_i[12]&frequency_counter_i[11]),
    .RGB2PWM (~ym_wr_strobe_n),
    .CURREN  (1'b1                                            ),
    .RGB0    (led_green                                       ), //Actual Hardware connection
    .RGB1    (led_blue                                        ),
    .RGB2    (led_red                                         )
  );
  defparam RGB_DRIVER.RGB0_CURRENT = "0b000001";
  defparam RGB_DRIVER.RGB1_CURRENT = "0b000001";
  defparam RGB_DRIVER.RGB2_CURRENT = "0b000001";
*/
  wire rst;
  assign rst = !rst_n;

//    assign dbg_1 = sh;

    wire [7:0] data_in;
    wire [7:0] data_out;
    wire bus_read = !cs_n && !rd_n && wr_n;
    wire bus_write = !cs_n && !wr_n;
    assign data = bus_read ? data_out : 8'bZ;
    assign data_in = bus_write ? data : 8'hFF;
    reg cp1;

    reg [7:0] bus_data_in, bus_data_in_next;
    reg bus_wr_n, bus_wr_n_next;
    reg bus_a0, bus_a0_next;
    reg [2:0] bus_wr_q, bus_wr_q_next;

    always @(negedge bus_write or posedge rst) begin
        if (rst) begin
            bus_data_in[7:0] <= 7'b0;
            bus_wr_n <= 1'b1;
            bus_a0 <= 1'b0;
        end else begin
            bus_data_in[7:0] <= data[7:0];
            bus_wr_n <= wr_n; // ???? What causes bus_wr_n to become 1 again??
            bus_a0 <= a0;
        end
    end

    reg ym_wr_strobe_n;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bus_wr_q[2:0] <= 3'b0;
            ym_wr_strobe_n <= 1'b0; // || bus_wr_q[1:0] == 2'b10);
        end else begin
            bus_wr_q[2:0] <= {bus_wr_q[1:0], bus_write};
            ym_wr_strobe_n <= !(bus_wr_q[2:1] == 2'b10); // || bus_wr_q[1:0] == 2'b10);
        end
    end

    always @(negedge clk or posedge rst) begin
        if(rst) begin
            cp1 <= 1'b0;
        end else begin
            cp1 <= ~cp1;
        end
    end

  jt51 YM2151 (
	.rst(rst),
	.clk(clk),
	.cen(1'b1),
	.cen_p1(cp1),
	.cs_n(ym_wr_strobe_n), // .cs_n(cs_n),
	.wr_n(ym_wr_strobe_n),
	.a0(a0),
	.din(bus_data_in),//	.din(data),
	.dout(data_out),
	.ct1(ct1),
	.ct2(ct2),
	.irq_n(irq_n),
	.sample(sh),
	.xleft(ym_left),
	.xright(ym_right) //,
	//.dbg(dbg),
	//.dbg_data(dbg_data)
  );

    reg signed [23:0] dac_left_r;
    reg signed [23:0] dac_right_r;
	reg signed [15:0] ym_left_r;
	reg signed [15:0] ym_right_r;
	reg signed [15:0] ym_left_r_nxt;
	reg signed [15:0] ym_right_r_nxt;

    // reg signed [31:0] ym_left_mult;
    // reg signed [31:0] ym_right_mult;

    wire ym_sample_ready = ~clk & sh;

/*
    always @(posedge ym_sample_ready or posedge rst) begin
        if (rst) begin
			ym_left_r <= 24'b0;
			ym_right_r <= 24'b0;
        end else begin
			ym_left_r <= ym_left_r_nxt;
			ym_right_r <= ym_right_r_nxt;
//			ym_left_r <= ym_left_r + ym_left_r_nxt;
//			ym_right_r <= ym_right_r + ym_right_r_nxt;
        end
    end
*/
    localparam ym_amp_shift = 5;
	always @(*) begin
		ym_left_r_nxt = ym_left_r;
		ym_right_r_nxt = ym_right_r;

        // ym_left_mult = ym_left_r*16'd3;
        // ym_right_mult = ym_right_r*16'd3;

		if (sh) begin
			ym_left_r_nxt = ym_left[15:0];
			ym_right_r_nxt = ym_right[15:0];
		end
	end

    always @(posedge clk or posedge rst) begin
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
			dac_left_r <= {ym_left_r[15], ym_left_r[15], ym_left_r[15:0], ym_left_r[15:10]}; // ym_left_mult[16:1];
			dac_right_r <= {ym_right_r[15], ym_right_r[15], ym_right_r[15:0], ym_right_r[15:10]}; //ym_right_mult[16:1];
		end
	end

  reg hfclk_div2;
  reg hfclk_div4;

  always @(posedge hfclk or posedge rst) begin
    if (rst) hfclk_div2 <= 1'b0;
    else hfclk_div2 <= ~hfclk_div2;
  end

  always @(posedge hfclk_div2 or posedge rst) begin
    if (rst) hfclk_div4 <= 1'b0;
    else hfclk_div4 <= ~hfclk_div4;
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


/*
    input wire cs_n,
    input wire wr_n,
    input wire rd_n,
    input wire a0,

*/

    //assign dbg[3:0] = {clk, i2s_data, i2s_bck, i2s_lrck};

    //assign dbg_data[7:0] = data[7:0];

endmodule