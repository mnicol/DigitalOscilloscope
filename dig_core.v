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
	wire ram_trmt;
	wire [7:0] ram_tx_data;
	wire [7:0] cc_resp_data;
	reg [7:0] resp_data_ff;
	wire [15:0] EEP_cfg_data;
	wire eep_done;
	wire [2:0] og_addr;
	wire [23:0] ram_cmd;
	wire ram_cmd_rdy;
	reg [23:0] cmd_used;
	wire cmd_rdy_used;
	//wire send_resp_in;
	wire send_resp_cc;
	//wire ram_trmt_in;
	//reg ram_trmt_ff;
	wire dump_done;

	//assign send_resp = send_resp_ff;
	assign en = cap_en | dump_en;
	assign resp_data = resp_data_ff;
	//assign send_resp = send_resp_ff | ram_trmt_ff;
	assign send_resp = send_resp_cc | ram_trmt;
	//assign cmd_used = cmd_rdy ? cmd : ram_cmd;
	assign cmd_rdy_used = cmd_rdy | ram_cmd_rdy;

	always @(posedge clk)
		if (send_resp_cc)
			resp_data_ff <= cc_resp_data;
		else if (ram_trmt)
			resp_data_ff <= ram_tx_data;
		else
			resp_data_ff <= resp_data_ff;

	always @(posedge clk)
		if (ram_cmd_rdy)
			cmd_used <= ram_cmd;
		else if (cmd_rdy)
			cmd_used <= cmd;
		else
			cmd_used <= cmd_used;
	
	//always@(posedge clk) send_resp_ff <= send_resp_in;
	//always@(posedge clk) ram_trmt_ff <= ram_trmt_in;
 
  ///////////////////////////////////////////////////////
  // Instantiate the blocks of your digital core next //
  /////////////////////////////////////////////////////
Analog_Interface iAnaI(.clk(clk), .adc_clk(adc_clk), .rst_n(rst_n), .trig1(trig1), .trig2(trig2),
			.decimator(decimator), .trig_cfg(trig_cfg), .trig_pos(trig_pos), .rclk(rclk),
			.set_cap_done(set_cap_done), .en(cap_en), .we(we), .addr(cap_addr), .trace_end(trace_end));

RAM_Interface iRAMI(.clk(clk), .rst_n(rst_n), .trace_end(trace_end), .cap_en(cap_en),
			.cap_addr(cap_addr), .dump_en(dump_en), .dump_chan(dump_chan), .we(we), .ch1_rdata(ch1_rdata),
			.ch2_rdata(ch2_rdata), .ch3_rdata(ch3_rdata), .og_data(EEP_cfg_data), .data_valid(eep_done),
			.addr(addr), .en(en), .ram_trmt(ram_trmt), .tx_done(resp_sent), .ram_tx_data(ram_tx_data),
			.cmd_rdy(ram_cmd_rdy), .cmd(ram_cmd), .og_addr(og_addr), .set_done(dump_done));//, .clr_cmd_rdy(clr_cmd_rdy));

Cmd_Config iCC(.clk(clk), .rst_n(rst_n), .SPI_data(SPI_data), .wrt_SPI(wrt_SPI), .ss(ss),
			.SPI_done(SPI_done), .EEP_data(EEP_data), .cmd(cmd_used), .cmd_rdy(cmd_rdy_used),
			.clr_cmd_rdy(clr_cmd_rdy), .resp_data(cc_resp_data), .send_resp(send_resp_cc),
			.resp_sent(resp_sent), .decimator(decimator), .set_cap_done(set_cap_done),
			.dump_chan(dump_chan), .dump_en(dump_en), .trig_cfg(trig_cfg), .trig_pos(trig_pos), 
			.EEP_cfg_data(EEP_cfg_data), .eep_done(eep_done), .gain_addr(og_addr), .dump_done(dump_done));
  
endmodule
  