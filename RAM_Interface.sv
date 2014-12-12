module RAM_Interface(clk, rst_n, trace_end, cap_en, cap_addr, dump_en, dump_chan, we, 
										ch1_rdata, ch2_rdata, ch3_rdata, og_data, data_valid, addr, en,
										ram_trmt, tx_done, ram_tx_data, cmd_rdy, cmd, og_addr);//, clr_cmd_rdy);

/////////////////////////////////////////
// 		 Inputs 	                      //
///////////////////////////////////////
input logic clk, rst_n, cap_en, dump_en, we, tx_done;
input logic [8:0] trace_end, cap_addr;
input logic [1:0] dump_chan;
input logic [7:0] ch1_rdata, ch2_rdata, ch3_rdata;
input logic [7:0] og_data;
input logic [2:0] og_addr;
input logic data_valid;
//input logic clr_cmd_rdy;

/////////////////////////////////////////
// 		 Outputs 	                      //
///////////////////////////////////////
output logic en, ram_trmt, cmd_rdy;
output logic [8:0] addr;
output logic [7:0] ram_tx_data;
output logic [23:0] cmd;

/////////////////////////////////////////
// 		 Logic   	                      //
///////////////////////////////////////
logic strt_dump, incr_addr;
logic [8:0] dump_addr;
logic [7:0] gain;
logic [7:0] offset;
logic [7:0] rdata;
logic [1:0] cmd_cnt;
logic store_offset;
logic store_gain;
logic done;
logic set_cmd_rdy;
logic ram_trmt_ff1, ram_trmt_ff2;
//logic clr_cmd_rdy;

/////////////////////////////////////////
// 		 States  	                      //
///////////////////////////////////////
typedef enum reg [1:0] {IDLE, READ, WAIT, GET_OG} state_t;
state_t state, nxt_state;

always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end

//////////////////////////////////////////////
// Delay ram_trmt until resp_data ready    //
////////////////////////////////////////////
always_ff @(posedge clk) begin
	ram_trmt_ff2 <= ram_trmt_ff1;
	ram_trmt <= ram_trmt_ff2;
end

/////////////////////////////////////////
// 		 uhhhhhhhhhhhhhhhh              //
///////////////////////////////////////
//always_ff @(posedge clk) begin
//	if (&cmd_cnt && data_valid)
//		cmd_rdy <= 1'b0;
//	else if (set_cmd_rdy)
//		cmd_rdy <= 1'b1;
//	else
//		cmd_cnt <= cmd_cnt;
//end

/////////////////////////////////////////
// 		 Set cmd 	                      //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (|cmd_cnt)
		cmd <= {8'h09, 2'b00, og_addr, dump_chan, 9'h100};
	else
		cmd <= {8'h09, 2'b00, og_addr, dump_chan, 9'h000};
end

/////////////////////////////////////////
// 		 Increment cmd_cnt              //
///////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		cmd_cnt <= 2'b00;
	else if (tx_done)
		cmd_cnt <= 2'b00;
	else if (set_cmd_rdy)
		cmd_cnt <= cmd_cnt + 1;
	else
		cmd_cnt <= cmd_cnt;
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
assign done = (addr == trace_end) ? 1'b1 : 1'b0;

/////////////////////////////////////////
// 		 set rdata for read             //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (dump_chan == 0)
		rdata <= ch1_rdata;	
	else if (dump_chan == 1)
		rdata <= ch2_rdata;
	else
		rdata <= ch3_rdata;
end

/////////////////////////////////////////
// 		 set offset                     //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (store_offset)
		offset <= og_data;
	else
		offset <= offset;
end	

/////////////////////////////////////////
// 		 set gain                       //
///////////////////////////////////////
always_ff @(posedge clk) begin
	if (store_gain)
		gain <= og_data;
	else
		gain <= gain;
end	

always_comb begin
	strt_dump = 1'b0;
	incr_addr = 1'b0;
	ram_trmt_ff1 = 1'b0;
	set_cmd_rdy = 1'b0;
	//clr_cmd_rdy = 1'b0;
	store_offset = 1'b0;
	store_gain = 1'b0;
	cmd_rdy = 0;
	nxt_state = IDLE;

	case (state)
		IDLE: if (!we & en) begin
				nxt_state = GET_OG;
				//set_cmd_rdy = 1'b1;
				cmd_rdy = 1;
			end
			else nxt_state = IDLE;

		READ: if (done) begin
				nxt_state = IDLE;
			end
			else begin
				ram_trmt_ff1 = 1'b1;
				nxt_state = WAIT;
			end

		WAIT: if (tx_done) begin
				incr_addr = 1'b1;
				nxt_state = READ;
			end
			else nxt_state = WAIT;

		GET_OG: if (&cmd_cnt && data_valid) begin
				nxt_state = READ;
				store_gain = 1'b1;
				strt_dump = 1'b1;
			end
			else if (data_valid) begin
				nxt_state = GET_OG;
				//set_cmd_rdy = 1'b1;
				cmd_rdy = 1;
				store_offset = 1'b1;
			end
			else begin
				nxt_state = GET_OG;
				cmd_rdy = 1;
			end

		default: nxt_state = IDLE;

	endcase
	
end



/////////////////////////////////////////
// 		 offset/gain correction         //
///////////////////////////////////////

//logic signed [9:0] w1a, w1b;	// Signed to recognize neg values
//logic [15:0] w2a, w2b;

// Used if subtracting offset from unsigned raw data
//logic signed [7:0] opp_offset;
//assign opp_offset = ~(offset) + 1;

// Add or subtract offset and check if saturation needed
//assign w1a = offset[7] ? (rdata - opp_offset) : (rdata + offset);
//assign w1b = w1a[9] ? 8'h00 : ((w1a[8] & ~w1a[9]) ? 8'hFF : w1a);

// Multiply and check if saturation needed before dividing
//assign w2a = (gain * w1b);
//assign w2b = w2a[15] ? (15'h7FFF) : w2a;
//assign ram_tx_data = w2b[14:7];

logic [7:0] sum, sat_sum;
logic [15:0] prod, sat_prod;

assign sum = rdata + offset;
assign sat_sum = (~offset[7] && rdata[7] && ~sum[7]) ? 8'hff :
									(offset[7] && ~rdata[7] && sum[7]) ? 8'h00 : sum;
assign prod = sat_sum * gain;
assign sat_prod = (prod[15]) ? 16'h7fff : prod;
assign ram_tx_data = sat_prod[14:7];

endmodule
