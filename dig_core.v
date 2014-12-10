module dig_core(clk,rst_n,adc_clk,trig1,trig2,SPI_data,wrt_SPI,SPI_done,ss,EEP_data,
                rclk,en,we,addr,ch1_rdata,ch2_rdata,ch3_rdata,cmd,cmd_rdy,clr_cmd_rdy,
								resp_data,send_resp,resp_sent);
				
  input clk,rst_n;								// clock and active low reset
  output adc_clk,rclk;							// 20MHz clocks to ADC and RAM
  input trig1,trig2;							// trigger inputs from AFE
  output [15:0] SPI_data;						// typically a config command to digital pots or EEPROM
  output wrt_SPI;								// control signal asserted for 1 clock to initiate SPI transaction
  output [2:0] ss;								// determines which Slave gets selected 000=>trig, 001-011=>chX_ss, 100=>EEP
  input SPI_done;								// asserted by SPI peripheral when finished transaction
  input [7:0] EEP_data;							// Formed from MISO from EEPROM.  only lower 8-bits needed from SPI periph
  output en,we;									// RAM block control signals (common to all 3 RAM blocks)
  output [8:0] addr;							// Address output to RAM blocks (common to all 3 RAM blocks)
  input [7:0] ch1_rdata,ch2_rdata,ch3_rdata;	// data inputs from RAM blocks
  input [23:0] cmd;								// 24-bit command from HOST
  input cmd_rdy;								// tell core command from HOST is valid
  output clr_cmd_rdy;
  output [7:0] resp_data;						// response byte to HOST
  output send_resp;								// control signal to UART comm block that initiates a response
  input resp_sent;								// input from UART comm block that indicates response finished sending
  
  //////////////////////////////////////////////////////////////////////////
  // Interconnects between modules...declare any wire types you need here//
  ////////////////////////////////////////////////////////////////////////
	wire [3:0] decimator;
	wire [7:0] trig_cfg;
	wire [8:0] trig_pos;
	wire set_cap_done;
	wire en;
	wire we;
	wire [8:0] cap_addr;
	wire [8:0] trace_end;
	wire cap_en;
	wire dump_en;
	wire [1:0] dump_chan;
	wire [15:0] og1, og2, og3;
	wire ram_trmt;
	wire [7:0] ram_tx_data;
	wire cmd_trmt;
	wire [7:0] cmd_tx_data;

	assign en = cap_en | dump_en;
	assign tx_data = cmd_trmt ? cmd_tx_data : ram_tx_data;
	assign trmt = cmd_trmt | ram_trmt;
	
	
 
  ///////////////////////////////////////////////////////
  // Instantiate the blocks of your digital core next //
  /////////////////////////////////////////////////////
Analog_Interface iAnaI(.clk(clk), .adc_clk(adc_clk), .rst_n(rst_n), .trig1(trig1), .trig2(trig2),
			.decimator(decimator), .trig_cfg(trig_cfg), .trig_pos(trig_pos),
			.set_cap_done(set_cap_done), .en(en), .we(we), .addr(cap_addr), .trace_end(trace_end));

RAM_Interface iRAMI(.clk(clk), .rst_n(rst_n), .trace_end(trace_end), .cap_en(cap_en),
			.cap_addr(cap_addr), .dump_en(dump_en), .dump_chan(dump_chan), .we(we), .ch1_rdata(ch1_rdata),
			.ch2_rdata(ch2_rdata), .ch3_rdata(ch3_rdata), .og1(og1), .og2(og2), .og3(og3), .addr(addr),
			.en(en), .ram_trmt(ram_trmt), .tx_done(resp_sent), .ram_tx_data(ram_tx_data), .rclk(rclk));

Cmd_Config iCC(.clk(clk), .rst_n(rst_n), .SPI_data(SPI_data), .wrt_SPI(wrt_SPI), .ss(ss),
			.SPI_done(SPI_done), .EEP_data(EEP_data), .cmd(cmd), .cmd_rdy(cmd_rdy),
			.clr_cmd_rdy(clr_cmd_rdy), .resp_data(resp_data), .send_resp(send_resp),
			.resp_sent(resp_sent), .trmt(cmd_trmt), .tx_data(cmd_tx_data), .decimator(decimator),
			.dump_chan(dump_chan), .dump_en(dump_en), .og1(og1), .og2(og2), .og3(og3));
  
endmodule
  