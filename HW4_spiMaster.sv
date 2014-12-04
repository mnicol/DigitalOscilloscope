module	HW4_spiMaster(clk, rst_n, wrt, cmd, MISO, SCLK, MOSI, SS_n, done, data);

input clk, rst_n, wrt, MISO;
input [15:0] cmd;
output reg SCLK, MOSI, SS_n, done;
output reg [15:0] data;

///////////////////////////////////////////
// Define the four states of the FSM
///////////////////////////////////////////
typedef enum reg [1:0] {IDLE, TRANSMIT, BUFFER, WAIT} state_t;
state_t state, nxt_state;

logic clr_cnt;					// Clears clk and SCLK counters
logic [4:0] cnt_clk;		// Counts clk cycles to set SCLK
logic [4:0] cnt_SCLK;		// Count SCLK cycles to set when finished
logic trans16bits;			// Set to 1 when 16 bits have been transmitted
logic [15:0] shiftReg;	// Shifts one bit at a time out to MOSI

// Flip flops for incoming MISO bits
logic miff1, miff2, scff1, scff2, scff3, scff4, scff5, negSCLKmiso;

///////////////////////////////////////////
// Set states to update or reset
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

///////////////////////////////////////////
// Set/reset counters to generate SCLK
///////////////////////////////////////////
always_ff @(posedge clk, posedge clr_cnt)
	if (clr_cnt)
		cnt_clk <= 0'b00000;
	else
		cnt_clk <= cnt_clk + 1;

///////////////////////////////////////////
// Count number of times SCLK is high
///////////////////////////////////////////
always_ff @(posedge SCLK, posedge clr_cnt)
	if (clr_cnt)
		cnt_SCLK <= 0'b00000;
	else
		cnt_SCLK <= cnt_SCLK + 1;

///////////////////////////////////////////
// Set MOSI
///////////////////////////////////////////
always_ff @(negedge SCLK, posedge clr_cnt)
	if (clr_cnt)
		shiftReg <= cmd;
	else
		shiftReg <= {shiftReg, 1'b0};

///////////////////////////////////////////
// State transition logic
///////////////////////////////////////////
always_comb begin
	// Defaults
	SCLK = cnt_clk[4]; // SCLK alternates high/low every 16 clk cycles
	SS_n = 1;
	clr_cnt = 0;
	trans16bits = cnt_SCLK[4];
	nxt_state = IDLE;
	MOSI = 1'bz;
	done = 0;

	case(state)

	//////////////////////////////////////////////////////////////
	// Move to TRANSITION when wrt signal received and set SS_n
	// to active (low)
	//////////////////////////////////////////////////////////////
	IDLE: if (!wrt) begin
			clr_cnt = 1;
			nxt_state = IDLE;
		end
		else begin
			clr_cnt = 1;
			SS_n = 0;
			nxt_state = TRANSMIT;
		end

	//////////////////////////////////////////////////////////////
	// Set transmission value. When 16 bits have been transmitted,
	// wait until next falling SCLK edge and transition to BUFFER
	//////////////////////////////////////////////////////////////
	TRANSMIT: begin
		MOSI = shiftReg[15];
		SS_n = 0;
		if (!trans16bits | SCLK)
			nxt_state = TRANSMIT;
		else
			nxt_state = BUFFER;
		end

	//////////////////////////////////////////////////////////////
	// Stay in buffer for 8 clk cycles then move to WAIT
	//////////////////////////////////////////////////////////////
	BUFFER: if (!(&cnt_clk[2:0])) begin
			SS_n = 0;
			MOSI = shiftReg[15];
			nxt_state = BUFFER;
		end
		else begin
			nxt_state = WAIT;
		end

	//////////////////////////////////////////////////////////////
	// Set done bit and move to IDLE
	//////////////////////////////////////////////////////////////
	WAIT: begin done = 1;
		nxt_state = IDLE;
		end

	default: nxt_state = IDLE;

	endcase

end


///////////////////////////////////////////
// Flop MISO
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		miff1 <= 0;
		miff2 <= 0;

		scff1 <= 0;
		scff2 <= 0;
		scff3 <= 0;
		scff4 <= 0;
		scff5 <= 0;
	end
	else begin
		miff1 <= MISO;
		miff2 <= miff1;

		scff1 <= SCLK;
		scff2 <= scff1;
		scff3 <= scff2;
		scff4 <= scff3;
		scff5 <= scff4;
	end
	negSCLKmiso <= (~scff4 & scff5);
end

///////////////////////////////////////////
// Shift MISO bits in
///////////////////////////////////////////
always_ff @(posedge negSCLKmiso)
	if (SS_n)
		data = 16'hzzzz;
	else
		data = {data[14:0], miff2};

endmodule

