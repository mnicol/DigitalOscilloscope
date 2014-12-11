`timescale 1ns/10ps
module DSO_dig_tb();
	
reg clk,rst_n;							// clock and reset are generated in TB

reg [23:0] cmd_snd;						// command Host is sending to DUT
reg send_cmd;
reg clr_resp_rdy;

reg [7:0] tx_data;
reg trmt;


wire adc_clk,MOSI,SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n;
wire TX,RX;

wire [15:0] cmd_ch1,cmd_ch2,cmd_ch3;			// received commands to digital Pots that control channel gain
wire [15:0] cmd_trig;							// received command to digital Pot that controls trigger level
wire cmd_sent,resp_rdy;							// outputs from master UART
wire [7:0] ch1_data,ch2_data,ch3_data;
wire trig1,trig2;

integer fd;

///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH  = 8'h01;		// Channel to dump specified in low 2-bits of second byte
localparam CFG_GAIN = 8'h02;		// Gain setting in bits [4:2], and channel in [1:0] of 2nd byte
localparam TRIG_LVL = 8'h03;		// Set trigger level, lower byte specifies value (46,201) is valid
localparam TRIG_POS = 8'h04;		// Set the trigger position. This is a 13-bit number, samples after capture
localparam SET_DEC  = 8'h05;		// Set decimator, lower nibble of 3rd byte. 2^this value is decimator
localparam TRIG_CFG = 8'h06;		// Write trig config.  2nd byte 00dettcc.  d=done, e=edge,
localparam TRIG_RD  = 8'h07;		// Read trig config register
localparam EEP_WRT  = 8'h08;		// Write calibration EEP, 2nd byte is address, 3rd byte is data
localparam EEP_RD   = 8'h09;		// Read calibration EEP, 2nd byte specifies address

//////////////////////
// Instantiate DUT //
////////////////////
DSO_dig iDUT(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.ch1_data(ch1_data),.ch2_data(ch2_data),
             .ch3_data(ch3_data),.trig1(trig1),.trig2(trig2),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
             .trig_ss_n(trig_ss_n),.ch1_ss_n(ch1_ss_n),.ch2_ss_n(ch2_ss_n),.ch3_ss_n(ch3_ss_n),
			 .EEP_ss_n(EEP_ss_n),.TX(TX),.RX(RX),.LED_n());
			   
///////////////////////////////////////////////
// Instantiate Analog Front End & A2D Model //
/////////////////////////////////////////////
AFE_A2D iAFE(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.ch1_ss_n(ch1_ss_n),.ch2_ss_n(ch2_ss_n),.ch3_ss_n(ch3_ss_n),
             .trig_ss_n(trig_ss_n),.MOSI(MOSI),.SCLK(SCLK),.trig1(trig1),.trig2(trig2),.ch1_data(ch1_data),
			 .ch2_data(ch2_data),.ch3_data(ch3_data));
			 
/////////////////////////////////////////////
// Instantiate UART Master (acts as host) //
///////////////////////////////////////////
//UART_comm_mstr iMSTR(.clk(clk), .rst_n(rst_n), .RX(TX), .TX(RX), .cmd(cmd_snd), .send_cmd(send_cmd),
//                     .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp_rcv), .clr_resp_rdy(clr_resp_rdy));
UART_comm iUARTMSTR(.clk(clk), .rst_n(rst_n), .tx_data(tx_data), .trmt(trmt), .TX(RX), .tx_done(tx_done), .RX(TX),
							.clr_cmd_rdy(clr_resp_rdy), .cmd_rdy(resp_rdy));


/////////////////////////////////////
// Instantiate Calibration EEPROM //
///////////////////////////////////
SPI_EEP iEEP(.clk(clk),.rst_n(rst_n),.SS_n(EEP_ss_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
	
//Function to send 3 byte commands via the uart to the dso dig
task send_full_cmd(input [23:0] full_cmd);
begin
	//Send the first byte (upper Byte)
		@(posedge clk)
			tx_data = full_cmd [23:16];

		@(posedge clk)
			trmt = 1'b1;

		@(negedge clk)
			trmt = 1'b0;

		@(posedge tx_done)
			#1; //ready for next byte


	//Send the second byte (middle Byte)
		@(posedge clk)
			tx_data = full_cmd [15:8];

		@(posedge clk)
			trmt = 1'b1;

		@(negedge clk)
			trmt = 1'b0;

		@(posedge tx_done)
			#1; //ready for next byte
			 

	//Send the final byte (lower Byte)
		@(posedge clk)
			tx_data = full_cmd [7:0];

		@(posedge clk)
			trmt = 1'b1;

		@(negedge clk)
			trmt = 1'b0;

		@(posedge tx_done)
			#1; //The TX is done with the full cmd
			 
end
endtask



initial begin
	clk = 0;
	rst_n = 0;			// assert reset
	clr_resp_rdy = 1'b0;
	trmt = 1'b0;

////////setup////////

//// EEP_WRT ////
	send_full_cmd({EEP_WRT,8'b00101010, 8'hBB});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hA5) begin
			$strobe("--------------------------------------------------------------");
			$strobe("--     EEPROM Write       -- Fail ---- Ack is %h not 0xA5 --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--     EEPROM Write       -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;



//// EEP_RD ////
	send_full_cmd({EEP_RD, 8'b00101010, 8'hFF});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hBB) begin
			$strobe("--------------------------------------------------------------");
			$strobe("--      EEPROM Read       -- Fail ---- Data: %h  ( 0xBB ) --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--      EEPROM Read       -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;


//// CFG_GAIN ////
	send_full_cmd({CFG_GAIN, 8'b000_111_00/*8'b000_ggg_cc*/, 8'hFF});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hA5)begin
			$strobe("--------------------------------------------------------------");
		 	$strobe("--   Config Gain Write    -- Fail ---- (Ack %h not 0xA5) --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--   Config Gain Write    -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;


//// TRIG_CFG ////
	send_full_cmd({TRIG_CFG, 8'b00_0_1_10_00/*8'b00_d_e_tt_cc*/, 8'hFF});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hA5) begin
			$strobe("--------------------------------------------------------------");
			$strobe("--  Trigger Config Write  -- Fail ---- (Ack is %h not 0xA5) --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--  Trigger Config Write  -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;


//// TRIG_LVL ////
	send_full_cmd({TRIG_LVL, 8'hFF, 8'h80});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hA5) begin
			$strobe("--------------------------------------------------------------");
			$strobe("--   Trigger Level Write  -- Fail ---- (Ack %h not 0xA5) --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--   Trigger Level Write  -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;


//// TRIG_POS ////
	send_full_cmd({TRIG_POS, 8'b0000_0000, 8'h80});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hA5) begin
			$strobe("--------------------------------------------------------------");
			$strobe("-- Trigger Position Write -- Fail ---- (Ack %h not 0xA5) --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else if ( iDUT.iDC.iCC.trig_pos != 9'h80) begin
			$strobe("--------------------------------------------------------------");
			$strobe("------   Trig Pos Internal Wrong: %h should be 0x80   ------", iDUT.iDC.iCC.trig_pos );
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("-- Trigger Position Write -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;


//// SET_DEC ////
	send_full_cmd({SET_DEC, 8'hFF, 8'h02});

	//Check for valid result
	if(iUARTMSTR.rx_data != 8'hA5) begin
			$strobe("--------------------------------------------------------------");
			$strobe("--      Set Decimator     -- Fail ---- (Ack %h not 0xA5) --", iUARTMSTR.rx_data );
			$strobe("--------------------------------------------------------------\n");
		end
	else if( iDUT.iDC.iCC.decimator != 8'h02 ) begin
			$strobe("--------------------------------------------------------------");
			$strobe("------  Decimator Internal Wrong: %h should be 0x02  ------", iDUT.iDC.iCC.decimator);
			$strobe("--------------------------------------------------------------");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--      Set Decimator     -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;

	repeat(100) @(negedge clk); //wait for everything to be done and spacer

//// TRIG_RD ////
	send_full_cmd({TRIG_RD, 8'hBA, 8'hE0});

	//Check if the config data is correct
	if(iUARTMSTR.rx_data != 8'b00111000) begin
			$strobe("--------------------------------------------------------------");
			$strobe("------------  Trig Read Fail: %h should be 0x38  -----------", iUARTMSTR.rx_data);
			$strobe("--------------------------------------------------------------\n");
		end
	else begin
			$strobe("--------------------------------------------------------------");
			$strobe("--       Trig Read        -- Pass ----------------------------");
			$strobe("--------------------------------------------------------------\n");
		end
	@(negedge clk)	clr_resp_rdy = 1'b1;
	@(negedge clk)	clr_resp_rdy = 1'b0;

	repeat(50) @(negedge clk); //Wait for some clk cycles

////////send dump////////

	fd = $fopen("DUMP.txt");


	//DUMP_CH    	// Channel to dump specified in low 2-bits of second byte
	send_full_cmd({DUMP_CH, 8'b0000_0000/*8'b0000_00cc*/, 8'hFF});

	repeat (510) 
	begin
		if(!resp_rdy)
        	@(posedge resp_rdy)

		$fdisplay(fd, "%h", iUARTMSTR.rx_data);//store rx_data to file or check to see if it's the right value?

      	@(negedge clk)  clr_resp_rdy = 1;
      	@(negedge clk)  clr_resp_rdy = 0;
  	end

	repeat (30) @(negedge clk); //make sure dump isdone 

	$fclose(fd);

	$stop();

end


always
  #1 clk = ~clk;

endmodule
