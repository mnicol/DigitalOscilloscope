module Cmd_Config(clk, rst_n, SPI_data, wrt_SPI, ss, SPI_done, EEP_data,
		 cmd, cmd_rdy, clr_cmd_rdy, resp_data, send_resp, resp_sent);

/////////////////////////////////////////
// 		 Inputs 	                  //
///////////////////////////////////////
input logic clk, rst_n, SPI_done, cmd_rdy, resp_sent;

input logic [7:0] EEP_data;
input logic [23:0] cmd;

/////////////////////////////////////////
// 		 Outputs 	                  //
///////////////////////////////////////
output logic wrt_SPI, clr_cmd_rdy, send_resp;

output logic [2:0] ss;
output logic [7:0] resp_data;
output logic [15:0] SPI_data;


///////////////////////////////////////////
// Define the two states of the FSM     //
/////////////////////////////////////////
typedef enum reg [1:0] {IDLE, PROC_CMD, RX_SPI}state_t;
state_t state, nxt_state;

///////////////////////////
// Upadte FSM state.    //
/////////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
    		state <= nxt_state;


///////////////////////////////////////////////////
// Logic to determine next state and outputs    //
/////////////////////////////////////////////////
always_comb begin
	//Default values
	ss = 3'b111;
	wrt_SPI = 0;
	SPI_data = 16'hxxxx;
	nxt_state = IDLE;
	
	case (state)

		IDLE: if (cmd_rdy)
			begin
				nxt_state = PROC_CMD;
			end
		else
			begin
				nxt_state = IDLE;
			end

		PROC_CMD: 
		begin
			casex(cmd[23:16])
				8'hx1:	begin	//TODO: Not Implemented Yet
							nxt_state = IDLE;
						end

				8'hx2:	begin
							ss = {0,cmd[9:8]};	//select the channel to send data to

							//Select comand to send based on gain number
							case(cmd[12:10])
								3'b000:	SPI_data = 16'h1302;
								3'b001:	SPI_data = 16'h1305;
								3'b010:	SPI_data = 16'h1309;
								3'b011:	SPI_data = 16'h1314;
								3'b100:	SPI_data = 16'h1328;
								3'b101:	SPI_data = 16'h1346;
								3'b110:	SPI_data = 16'h136B;
								3'b111: SPI_data = 16'h13DD;
								default: SPI_data = 16'h0000;
							endcase
							wrt_SPI = 1;
							nxt_state = IDLE;
						end

				8'hx3:	begin
							// Write to triggers
							ss = 3'b000;

							//specify trigger level in comand to send adjusted to be between 46 and 201
							if(cmd[7:0] < 46)
								SPI_data = {8'h13, 8'h2E}; // Saturate to 46
							else if(cmd[7:0] > 201)
								SPI_data = {8'h13, 8'hC9};	// Saturate to 201
							else
								SPI_data = {8'h13, cmd[7:0]};
							wrt_SPI = 1;
							nxt_state = IDLE;
						end

				8'hx4:	begin	//TODO: Not Implemented Yet
							nxt_state = IDLE;
						end

				8'hx5:	begin	//TODO: Not Implemented Yet
							nxt_state = IDLE;
						end

				8'hx6:	begin	//TODO: Not Implemented Yet
							nxt_state = IDLE;
						end

				8'hx7:	begin	//TODO: Not Implemented Yet
							nxt_state = IDLE;
						end

				8'hx8:	begin
							ss = 3'b100;	// Select EEPROM
							SPI_data = {2'b01, cmd[13:0]};
							wrt_SPI = 1;
							nxt_state = IDLE;
						end

				8'hx9:	begin
							ss = 3'b100;	// Select EEPROM
							SPI_data = {2'b00, cmd[13:8], 8'hxx};
							wrt_SPI = 1;
							nxt_state = RX_SPI;
						end

				default: nxt_state = IDLE;	//If invalid opcode is received do nothing

			endcase
		end

		RX_SPI: if(!SPI_done)
				begin
					// Wait for valid data
					nxt_state = RX_SPI;
				end
		else	begin
					//read data
					nxt_state = IDLE;
				end
	endcase
end

endmodule
