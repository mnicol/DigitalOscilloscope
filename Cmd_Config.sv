module Cmd_Config(clk, rst_n, SPI_data, wrt_SPI, ss, SPI_done, EEP_data,
			 cmd, cmd_rdy, clr_cmd_rdy, resp_data, send_resp, resp_sent,
			decimator, dump_chan, dump_en, trig_cfg, trig_pos, EEP_cfg_data, eep_done, gain_addr);



/////////////////////////////////////////
// 		 Inputs 	                  //
///////////////////////////////////////
input logic clk, rst_n, SPI_done, cmd_rdy, resp_sent;

input logic [7:0] EEP_data;
input logic [23:0] cmd;


/////////////////////////////////////////
// 		 Outputs 	                  //
///////////////////////////////////////
output logic wrt_SPI, clr_cmd_rdy, send_resp, dump_en, eep_done;

output logic [1:0] dump_chan;
output logic [2:0] ss, gain_addr;
output logic [3:0] decimator;

output logic [7:0] trig_cfg;
output logic [7:0] resp_data, EEP_cfg_data;
output logic [8:0] trig_pos;
output logic [15:0] SPI_data;


/////////////////////////////////////////
// 		 Internals 	                    //
///////////////////////////////////////
//logic [7:0] EEP_cfg_data_set, tx_data_set;
//logic [1:0] dump_chan_set;
//logic [8:0] trig_pos_set;
//logic [3:0] decimator_set;
//logic [5:0] trig_cfg_set;

logic eep_set, tx_set, dec_set, dump_chan_set, dec_set_en, trig_pos_set, 
							trig_set, gain_addr_set;

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

always_ff @(posedge clk)
	if(eep_set)
		EEP_cfg_data <= EEP_data;
	else
		EEP_cfg_data <= EEP_cfg_data;

always_ff @(posedge clk)
	if(tx_set)
		resp_data <= trig_cfg;
	else
		resp_data <= resp_data;

always_ff @(posedge clk)
	if(dump_chan_set)
		dump_chan <= cmd[9:8];
	else
		dump_chan <= dump_chan;

always_ff @(posedge clk)
	if(trig_pos_set)
		trig_pos <= cmd[8:0];
	else
		trig_pos <= trig_pos;

always_ff @(posedge clk)
	if(dec_set)
		decimator <= cmd[3:0];
	else
		decimator <= decimator;

always_ff @(posedge clk)
	if(trig_set)
		trig_cfg[5:0] <= cmd[13:8];
	else
		trig_cfg <= trig_cfg;

always_ff @(posedge clk)
	if(gain_addr_set)
		gain_addr <= cmd[12:10];
	else
		gain_addr <= gain_addr;

always_ff @(posedge clk)
	eep_done <= eep_set;

///////////////////////////////////////////////////
// Logic to determine next state and outputs    //
/////////////////////////////////////////////////
always_comb begin
	//Default values
	ss = 3'b111;
	wrt_SPI = 0;
	SPI_data = 16'hxxxx;
	dump_en = 1'b0;
 	send_resp = 1'b0;
	eep_set = 0;
	tx_set = 0;
	dump_chan_set = 0;
	dec_set = 0;
	trig_pos_set = 0;
	trig_set = 0;
	gain_addr_set = 0;
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

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h01 8?b000000cc 8?hxx				 			 		 *
 *																 *
 * Dump channel command. Channel to dump to UART is specified in *
 *  the lower 2-bits of thetrmt = 1'b1; 2nd byte. cc=00 implies channel 1,   *
 *  cc=10 implies channel 3. and cc=11 is reserved				 *
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx1:	begin
							if( cmd[9:8] != 2'b11 ) begin
								//dump_chan_set = cmd[9:8];
								dump_chan_set = 1;
								dump_en = 1'b1;
							end
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h02 8?b000gggcc 8?hxx							 		 *
 *																 *
 * Configure analog gain of channel (this would correspond to 	 *
 *  volts/div on an opamp). Channel to set gain on is specified  *
 *  in lower 2-bits of the 2nd byte (cc). Analog gain value is   *
 *  specified by the 3-bit ggg field of the 2nd byte. See 		 *
 *  section AFE Gain Settings below for how this will translate  *
 *  to SPI commands. 3- bit registers storing the current gain   *
 *  for each will be used for accessing the proper calibration   *
 *  coefficients from EEPROM.									 *
 * 																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
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
							//gain = cmd[12:10];
							gain_addr_set = 1;
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h03 8?hxx 8?hLL								 		 *
 *																 *
 * Set trigger level. This command is used to set the trigger 	 *
 *  level. The value in the 3rd byte (8?hLL) determines the	 	 *
 *  trigger level. Only values between 46 and 201 are valid. 	 *
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx3:	begin
							// Write to triggers
							ss = 3'b000;

							// Specify trigger level in comand to 
							// 	send adjusted to be between 46 and 201
							if(cmd[7:0] < 46)
								SPI_data = {8'h13, 8'h2E}; // Saturate to 46
							else if(cmd[7:0] > 201)
								SPI_data = {8'h13, 8'hC9};	// Saturate to 201
							else
								SPI_data = {8'h13, cmd[7:0]};
							wrt_SPI = 1;
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE 														 *
 * CMD: 8?h04 8?h0U 8?hLL								 		 *
 *																 *
 * Write the trigger position register. Determines how many 	 *
 *  samples to capture after the trigger occurs. This is a 9-bit *
 *  value.														 *
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx4:	begin
							//trig_pos_set = cmd[8:0];
							trig_pos_set = 1;
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h05 8?hxx 8?h0L								 		 *
 *																 *
 * Set decimator (essentially the sample rate). A 4-bit value is *
 *  specified in bits[3:0] of the 3rd byte.						 *
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx5:	begin
							//decimator_set = cmd[3:0];
							dec_set = 1;
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h06 8?b00dettcc 8?hxx							 		 *
 *																 *
 * Write trig_cfg register. This command is used to clear the 	 *
 *  capture_done bit (bit[5] = d). This command is also used to  *
 *  configure the trigger parameters(edge, trigger type, channel)*
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx6:	begin
							//trig_cfg_set[5:0] = cmd[13:8];
							trig_set = 1;
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h07 8?hxx 8?hxx							 	 	 	 *
 *																 *
 * Read trig_cfg register. The trig_cfg register 				 *
 *  (described below) is sent out the UART.	 					 *
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx7:	begin
							//tx_data_set = {2'b00, trig_cfg[5:0]};
							tx_set = 1;
							send_resp = 1'b1; //Might need extra state to wait for done
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE															 *
 * CMD: 8?h08 8?b00aaaaaa 8?hVV 						 		 *
 *																 *
 * Write location specified by 6-bit address of calibration 	 *
 *  EEPROM with data specified in the 3rd byte.					 *
 *          													 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx8:	begin
							ss = 3'b100;	// Select EEPROM
							SPI_data = {2'b01, cmd[13:0]};
							wrt_SPI = 1;
							nxt_state = IDLE;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE											 				 *
 * CMD: 8?h09 8?b00aaaaaa 8?hxx 		 				 		 *
 *												 				 *
 * Read calibration EEPROM location specified by 6-bit addres	 *
 *												 				 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				8'hx9:	begin
							ss = 3'b100;	// Select EEPROM
							SPI_data = {2'b00, cmd[13:8], 8'hxx};
							wrt_SPI = 1;
							nxt_state = RX_SPI;
						end

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * DONE														 	 *
 * Default Case:  If invalid opcode is received do nothing		 *
 *																 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
				default: nxt_state = IDLE;

			endcase
		end

		RX_SPI: if(!SPI_done)
				begin
					// Wait for valid data
					nxt_state = RX_SPI;
				end
		else	begin
					//read data
					//EEP_cfg_data_set = EEP_data;
					eep_set = 1;
					nxt_state = IDLE;
				end
	endcase
end

endmodule
