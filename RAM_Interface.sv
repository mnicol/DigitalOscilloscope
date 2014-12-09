module RAM_Interface(clk, trace_end, cap_en, cap_addr, dump_en, dump_chan, we, 
										ch1_rdata, ch2_rdata, ch3_rdata, og1, og2, og3, addr, en,
										ram_trmt, tx_done, ram_tx_data);

/////////////////////////////////////////
// 		 Inputs 	                      //
///////////////////////////////////////
input logic clk, cap_en, dump_en, we, tx_done;
input logic [8:0] trace_end, cap_addr;
input logic [1:0] dump_chan;
input logic [7:0] ch1_rdata, ch2_rdata, ch3_rdata;
input logic [15:0] og1, og2, og3;

/////////////////////////////////////////
// 		 Outputs 	                      //
///////////////////////////////////////
output logic en, ram_trmt;
output logic [8:0] addr;
output logic [7:0] ram_tx_data;

/////////////////////////////////////////
// 		 Logic   	                      //
///////////////////////////////////////
logic strt_dump, incr_addr;
logic [8:0] dump_addr;
logic [7:0] gain;
logic signed [7:0] offset;
logic [7:0] rdata;


typedef enum reg [1:0] {IDLE, READ, WAIT} state_t;
state_t state, nxt_state;

always @(posedge clk) begin
	state <= nxt_state;
end


/////////////////////////////////////////
// 		 Set en  	                      //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (we)
		en <= cap_en;
	else
		en <= dump_en;
end

/////////////////////////////////////////
// 		 Set addr	                      //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (we)
		addr <= cap_addr;
	else if (strt_dump)
		addr <= trace_end + 1;
	else if (incr_addr)
		addr <= addr + 1;
	else
		addr <= addr;
end

/////////////////////////////////////////
// 		 set rdata for read             //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (dump_chan == 0) begin
		rdata <= ch1_rdata;	
		offset <= og1[7:0];
		gain <= og1[15:8];
	end
	else if (dump_chan == 1) begin
		rdata <= ch2_rdata;
		offset <= og2[7:0];
		gain <= og2[15:8];
	end
	else begin
		rdata <= ch3_rdata;
		offset <= og3[7:0];
		gain <= og3[15:8];
	end
end

always_comb begin
	strt_dump = 1'b0;
	incr_addr = 1'b0;
	ram_trmt = 1'b0;

	case (state)
		IDLE: if (!we & en) begin
				nxt_state = READ;
				strt_dump = 1'b1;
			end
			else nxt_state = IDLE;

		READ: begin
				ram_trmt = 1'b1;
				nxt_state = WAIT;
			end

		WAIT: if (tx_done) begin
				incr_addr = 1'b1;
				nxt_state = READ;
			end
	endcase
	
end



/////////////////////////////////////////
// 		 offset/gain correction         //
///////////////////////////////////////
logic signed [9:0] w1a, w1b;	// Signed to recognize neg values
logic [15:0] w2a, w2b;

// Used if subtracting offset from unsigned raw data
logic signed [7:0] opp_offset;
assign opp_offset = ~(offset) + 1;

// Add or subtract offset and check if saturation needed
assign w1a = offset[7] ? (rdata - opp_offset) : (rdata + offset);
assign w1b = w1a[9] ? 8'h00 : ((w1a[8] & ~w1a[9]) ? 8'hFF : w1a);

// Multiply and check if saturation needed before dividing
assign w2a = (gain * w1b);
assign w2b = w2a[15] ? (15'h7FFF) : w2a;
assign ram_tx_data = w2b[14:7];

endmodule
