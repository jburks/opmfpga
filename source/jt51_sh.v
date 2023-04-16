/*  This file is part of JT51.

    JT51 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT51 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT51.  If not, see <http://www.gnu.org/licenses/>.
    
    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2016
    */


module jt51_sh #(parameter width=5, stages=32, rstval=1'b0, bram=0 ) (
    input                           rst,
    input                           clk,
    input                           cen,
    input       [width-1:0]         din,
    output      [width-1:0]         drop
);

genvar i;
generate

if (bram == 0) begin

reg [stages-1:0] bits[width-1:0];

for (i=0; i < width; i=i+1) begin: bit_shifter
    always @(posedge clk, posedge rst) begin
        if(rst)
            bits[i] <= {stages{rstval}};
        else if(cen)
            bits[i] <= {bits[i][stages-2:0], din[i]};
    end
    assign drop[i] = bits[i][stages-1];
end

end else begin

// Block RAM'd version, requires reset to hold for up to 32 clocks

reg [width-1:0] bits[255:0];
reg [width-1:0] dout;
reg [7:0] raddr = 8'b0;
reg [7:0] waddr = stages-1;

for (i=0; i < 32; i=i+1) begin
    initial bits[i] = {width{rstval}};
end

always @(posedge clk) begin
    if(rst || cen) begin
        dout <= bits[raddr];
        bits[waddr] <= rst ? {width{rstval}} : din;
        raddr <= {3'b0, raddr[4:0] + 5'b1};
        waddr <= {3'b0, waddr[4:0] + 5'b1};
    end
end

assign drop = rst ? {width{rstval}} : dout;
    
end

endgenerate

endmodule