module UART_comm(clk, rst_n, clr_cmd_rdy, trmt, tx_data, RX, 
								 cmd_rdy, cmd, tx_done, TX);

input clk, rst_n, clr_cmd_rdy, trmt, RX;
input reg [7:0] tx_data;
output reg cmd_rdy, tx_done, TX;
output reg [23:0] cmd;


logic clr_rdy, rdy;			// UART transciever signals
logic [7:0] rx_data;		// UART transciever's rx_data for setting cmd

logic ld_uppr, ld_mid;	// Signals for loading upper and middle bytes to cmd
logic set_cmd_rdy;			// Signals for updating cmd_rdy signal


///////////////////////////////////////////
// Define the three states of the FSM   //
/////////////////////////////////////////
typedef enum reg [1:0] {IDLE, UPPER, MIDDLE}state_t;
state_t state, nxt_state;


/////////////////////////////////////////
// Instantiate the UART transceiver   //
///////////////////////////////////////
UART UART_txrx(.clk(clk), .rst_n(rst_n), .tx_data(tx_data), .trmt(trmt), .TX(TX), 
							.tx_done(tx_done), .RX(RX), .clr_rdy(clr_rdy), .rx_data(rx_data), .rdy(rdy));


////////////////////////////////////////////////////////////
// Load rx_data into upper cmd bits if ld_uppr is high   //
//////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
	if (ld_uppr)
		cmd[23:16] <= rx_data;
	else
		cmd[23:16] <= cmd[23:16];
end


////////////////////////////////////////////////////////////
// Load rx_data into middle cmd bits if ld_mid is high   //
//////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
	if (ld_mid)
		cmd[15:8] <= rx_data;
	else
		cmd[15:8] <= cmd[15:8];
end


///////////////////////////////////////////
// Set bit indicating if cmd is ready   //
/////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		cmd_rdy <= 0;
	else if (clr_cmd_rdy)
		cmd_rdy <= 0;
	else if (set_cmd_rdy)
		cmd_rdy <= 1;
	else
		cmd_rdy <= cmd_rdy;
end

///////////////////////////////////////////////////////////////////////
// Upadte FSM state. Note there isn't a rst_n signal for this FSM   //
/////////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
	state <= nxt_state;
end


////////////////////////////////////////////////////////////
// Continuously assign rx_data into lowest bits of cmd   //
//////////////////////////////////////////////////////////
assign cmd[7:0] = rx_data;


/////////////////////////////////////////
// FSM logic                          //
///////////////////////////////////////
always_comb begin

///////////////DEFAULTS/////////////////
	set_cmd_rdy = 0;
	clr_rdy = 0;
	ld_uppr = 0;
	ld_mid = 0;
	nxt_state = IDLE;
	

	case (state)
//////////////////////////////////////////////////////////////////////////
// Transition to UPPER when first 2 bytes have been received and are   //
// ready to be loaded to upper bytes of cmd. Stay in UPPER until rdy  //
// signal for middle 2 bytes goes high and transition to MIDDLE, or  //
// transition to IDLE if clr_cmd_rdy resets the FSM                 //
/////////////////////////////////////////////////////////////////////
		UPPER: if (rdy) begin
				ld_mid = 1;
				clr_rdy = 1;
				nxt_state = MIDDLE;
			end
			else if (clr_cmd_rdy) begin
				nxt_state = IDLE;
			end
			else begin
				nxt_state = UPPER;
			end


//////////////////////////////////////////////////////////////////////////
// Transition to MIDDLE when second 2 bytes have been received and are //
// ready to be loaded to upper bytes of cmd. Stay in MIDDLE until rdy //
// signal for lower 2 bytes goes high and transition to IDLE, also   //
// transition to IDLE if clr_cmd_rdy resets the FSM                 //
/////////////////////////////////////////////////////////////////////
		MIDDLE: if (rdy) begin
				set_cmd_rdy = 1;
				clr_rdy = 1;
				nxt_state = IDLE;
			end
			else if (clr_cmd_rdy) begin
				nxt_state = IDLE;
			end
			else begin
				nxt_state = MIDDLE;
			end


//////////////////////////////////////////////////////////////////////////
// Transition to IDLE when final 2 bytes have been received and are    //
// ready to be loaded to lower bytes of cmd. Stay in IDLE until rdy   //
// signal for upper 2 bytes goes high and transition to UPPER,       //
//////////////////////////////////////////////////////////////////////
		default: if (rdy & !cmd_rdy) begin
				ld_uppr = 1;
				clr_rdy = 1;
				nxt_state = UPPER;
			end
			else begin
				nxt_state = IDLE;
			end

	endcase
end

endmodule
