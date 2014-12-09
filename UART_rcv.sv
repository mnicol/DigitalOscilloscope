module UART_rcv(clk, rst_n, RX, clr_rdy, rx_data, rdy);

input clk, rst_n, RX, clr_rdy;
output reg [7:0] rx_data;
output reg rdy;

logic rxff1, rxff2, rxff3, offset, rec, set_rdy, strt, sample, cnt8, pause, rst_cnt;
logic [3:0] bit_cnt;			// counts number of bits received
logic [5:0] baud_cnt;			// tracks when to sample bits

/////////////////////////////////////////
// Define the three states of the FSM //
///////////////////////////////////////
typedef enum reg [1:0] {IDLE, START, RECEIVE} state_t;
state_t state, nxt_state;

////////////////////////////////////
// Flip flop asynchronous inputs //
//////////////////////////////////
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		rxff1 <= 1;
		rxff2 <= 1;
		rxff3 <= 1;
	end
	else begin
		rxff1 <= RX;
		rxff2 <= rxff1;
		rxff3 <= rxff2;
	end
end
assign strt = (!rxff2 & rxff3);

////////////////////////////////////
// Set states to update or reset //
//////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

//////////////////////////////////////////
// Set/reset counter for bits received //
////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		bit_cnt = 4'b0000;
	else if (rst_cnt)
		bit_cnt = 4'b0000;
	else if (sample & ~pause)
		bit_cnt = bit_cnt + 1;
	else
		bit_cnt = bit_cnt;
end

//////////////////////////////////////
// Set/reset counter for baud rate //
////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		baud_cnt <= 6'b000000;
	else if (sample & ~pause)
		baud_cnt <= 6'b000000;
	else if (rec)
		baud_cnt <= baud_cnt + 1;
	else
		baud_cnt <= baud_cnt;
end

///////////////////////////////////////////////////
// Produce sample and offset bits from baud_cnt //
/////////////////////////////////////////////////
assign sample = ((baud_cnt == 6'b101011) | offset) ? 1'b1 : 1'b0;
assign offset = &(baud_cnt);

/////////////////////////////
// Move RX into rx_data   //
///////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		rx_data <= 8'b00000000;
	else if (sample)
		rx_data <= {RX, rx_data[7:1]};
	else
		rx_data <= rx_data;

end

//////////////////////////
// Set rdy bit         //
////////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		rdy <= 0;
	else if (clr_rdy)
		rdy <= 0;
	else if (set_rdy)
		rdy <= 1;
	else
		rdy <= rdy;

//////////////////////////////
// State transition logic  //
////////////////////////////
always_comb begin
	set_rdy = 0;				// Set when receive finished
	rec = 0;						// Set when receiving data
	cnt8 = bit_cnt[3];	// Set when 8 bits sampled
	pause = 0;					// Set when waiting 1.5 baud cycles
	rst_cnt = 0;
	nxt_state = IDLE;

	case(state)

	//////////////////////////////////////////////////////////////
	// Move to START when start bit detected in RX. Move to    //
	// RECEIVE after 1.5 baud rates have passed               //
	///////////////////////////////////////////////////////////
	START: if(offset) begin
			rec = 1;
			nxt_state = RECEIVE;
		end
		else begin
			rec = 1;
			pause = 1;
			nxt_state = START;
		end

	//////////////////////////////////////////////////////////////
	// Stay in RECEIVE until 8 bits have been sampled, then    //
	// Move to IDLE                                           //
	///////////////////////////////////////////////////////////
	RECEIVE: if(cnt8) begin
			set_rdy = 1;
			rst_cnt = 1;
			nxt_state = IDLE;
		end
		else begin
			rec = 1;
			nxt_state = RECEIVE;
		end

	//////////////////////////////////////////////////////////////
	// Default to IDLE. Stay in idle until strt bit of RX is   //
	// detected, then move to START                           //
	///////////////////////////////////////////////////////////
	default: if(strt) begin
			nxt_state = START;
			pause = 1;
			rec = 1;
		end
		else
			nxt_state = IDLE;

	endcase
end

endmodule
