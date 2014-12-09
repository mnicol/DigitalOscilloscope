module UART_tx(clk, rst_n, tx_data, trmt, TX, tx_done);

input clk, rst_n, trmt;
input reg [7:0] tx_data;
output reg TX, tx_done;

logic [3:0] bit_cnt;			// counts number of bits transmitted
logic [5:0] baud_cnt;			// counts clock cycles between bit transmissions
logic [9:0] tx_shft_reg; 	// shifts out tx_data bits
logic cnt10, shift, load, trans, set_done, clr_done, clr_cnt;

/////////////////////////////////////////
// Define the two states of the FSM   //
///////////////////////////////////////
typedef enum reg {LOAD, TRANSMIT} state_t;
state_t state, nxt_state;

////////////////////////////////////
// Set states to update or reset //
//////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= LOAD;
	else
		state <= nxt_state;

/////////////////////////////////////////////
// Set/reset counter for bits transmitted //
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		bit_cnt <= 4'b0000;
	else if (load)
		bit_cnt <= 4'b0000;
	else if (shift)
		bit_cnt <= bit_cnt + 1;
	else
		bit_cnt <= bit_cnt;
end

//////////////////////////////////////
// Set/reset counter for baud rate //
////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		baud_cnt <= 6'b000000;
	else if (load | shift)
		baud_cnt <= 6'b000000;
	else if (trans)
		baud_cnt <= baud_cnt + 1;
	else
		baud_cnt <= baud_cnt;
end

///////////////////////////////////////
// Produce shit bit from baud_cnt   //
/////////////////////////////////////
assign shift = (baud_cnt == 6'b101011) ? 1'b1 : 1'b0;

/////////////////////////////////////////////
// Load/shift bits into/out of shift reg  //
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		tx_shft_reg <= 8'h00;
	else if (load)
		tx_shft_reg <= {1'b1, tx_data, 1'b0};
	else if (shift)
		tx_shft_reg <= {1'b1, tx_shft_reg [9:1]};
	else
		tx_shft_reg <= tx_shft_reg;
end

//////////////////////
// Set tx_done bit //
////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		tx_done <= 0;
	else if (clr_done)
		tx_done <= 0;
	else if (set_done)
		tx_done <= 1;
	else
		tx_done <= tx_done;

/////////////////////////////
// State transition logic //
///////////////////////////
always_comb begin
	nxt_state = LOAD;
	load = 1;
	trans = 0;
	cnt10 = (bit_cnt[3] & bit_cnt[1]);
	TX = 1;
	set_done = 0;
	clr_done = 0;

	case (state)

	/////////////////////////////////////////////////////////////
	// Stay in LOAD until trmt bit detected, then move to     //
	// TRANSMIT                                              //
	//////////////////////////////////////////////////////////
	LOAD: if(trmt) begin
			nxt_state = TRANSMIT;
			clr_done = 1;
		end
		else begin
			nxt_state = LOAD;
		end

	/////////////////////////////////////////////////////////////
	// Stay in TRANSMIT until 10 bits have been transmitted,  //
	// then move back to LOAD                                //
	//////////////////////////////////////////////////////////
	TRANSMIT: if (!cnt10) begin
			TX = tx_shft_reg[0];
			load = 0;
			trans = 1;
			nxt_state = TRANSMIT;
		end
		else begin
			set_done = 1;
			nxt_state = LOAD;
		end

	//////////////////////////////////////////////////////////////
	// Default to LOAD                                         //
	////////////////////////////////////////////////////////////
	default: begin
			nxt_state = LOAD;
		end

	endcase
end

endmodule
