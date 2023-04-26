
module ebr_sh #(parameter width=5, stages=32, rstval=1'b0 ) (clk,
        rst,
        cen,
        din,
        drop) ;
    input clk ;
    input rst ;
    input cen ;
    input [(width-1):0] din ;
    output [(width-1):0] drop ;

    localparam addr_width = clog2(stages);

    (* syn_ramstyle="block_ram" *) reg [(width - 1):0] mem [((2 ** addr_width) - 1):0] ;

    reg [(addr_width - 1):0] wr_addr_r, wr_addr_next_r ;
    reg [(addr_width - 1):0] rd_addr_r, rd_addr_next_r ;
    reg [(addr_width - 1):0] wipe_addr_r, wipe_addr_next_r ;
    reg [(width-1):0] raw_read_r;

    always @* begin
        wr_addr_next_r = wr_addr_r;
        rd_addr_next_r = rd_addr_r;
        wipe_addr_next_r = wipe_addr_r;

        if (cen) begin
            wr_addr_next_r = wr_addr_r + 1'b1;
            rd_addr_next_r = rd_addr_r + 1'b1;
            wipe_addr_next_r = wipe_addr_r + 1'b1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_addr_r <= 6'b0;
            rd_addr_r <= 6'b1;
            raw_read_r <= {width{1'b0}};
        end else begin
            wr_addr_r <= wr_addr_next_r;
            rd_addr_r <= rd_addr_next_r;

            if (cen) begin
                raw_read_r <= mem[rd_addr_r];
            end
        end
    end

    always @(posedge clk) begin
        wipe_addr_r <= wipe_addr_next_r;
        if (cen) begin
            mem[rst ? wipe_addr_r : wr_addr_r] <= rst ? {width{rstval}} : din;
        end
    end

    assign drop = raw_read_r;

    function [31:0] clog2 ;
        input [31:0] value ;
        reg [31:0] num ;
        begin
            num = (value - 1) ;
            for (clog2 = 0 ; (num > 0) ; clog2 = (clog2 + 1))
                num = (num >> 1) ;
        end
    endfunction
endmodule





