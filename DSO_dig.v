`timescale 1ns/10ps
module DSO_dig(clk,rst_n,adc_clk,ch1_data,ch2_data,ch3_data,trig1,trig2,MOSI,MISO,
               SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n,TX,RX);
				
  input clk,rst_n;								// clock and active low reset
  output adc_clk;								// 20MHz clocks to ADC
  input [7:0] ch1_data,ch2_data,ch3_data;		// input data from ADC's
  input trig1,trig2;							// trigger inputs from AFE
  input MISO;									// Driven from SPI output of EEPROM chip
  output MOSI;									// SPI output to digital pots and EEPROM chip
  output SCLK;									// SPI clock (40MHz/16)
  output wire ch1_ss_n,ch2_ss_n,ch3_ss_n;			// SPI slave selects for configuring channel gains (active low)
  output wire trig_ss_n;								// SPI slave select for configuring trigger level
  output wire EEP_ss_n;								// Calibration EEPROM slave select
  output TX;									// UART TX to HOST
  input RX;										// UART RX from HOST
  //output LED_n;									// control to active low LED
  
  ////////////////////////////////////////////////////
  // Define any wires needed for interconnect here //
  //////////////////////////////////////////////////
  wire wrt_spi;
  wire [15:0] spi_cmd;
  wire spi_SS_n;
  wire spi_done;
  wire spi_data;

	wire [8:0] addr;
	wire en;
	wire we;
	
	wire clr_cmd_rdy;
	wire trmt;
	wire [7:0] tx_data;
	wire cmd_rdy;
	wire [23:0] cmd;
	wire tx_done;

	wire [15:0] SPI_data;
	wire wrt_SPI;
	wire SPI_done;
	wire [2:0]ss;
	wire [7:0] EEP_data;
	wire [8:0] resp_data;
	wire send_resp;
	wire resp_sent;
	wire [7:0] ch1_rdata, ch2_rdata, ch3_rdata;

	

  /////////////////////////////
  // Instantiate SPI master //
  ///////////////////////////
  SPI_mstr SpiMstr( .clk(clk), .rst_n(rst_n), .wrt(wrt_spi), .cmd(spi_cmd), .MISO(MISO), 
					.SCLK(SCLK), .MOSI(MOSI), .SS_n(spi_SS_n), .done(spi_done), .data(spi_data));

  ///////////////////////////////////////////////////////////////
  // You have a SPI master peripheral with a single SS output //
  // you might have to do something creative to generate the //
  // 5 individual SS needed (3 AFE, 1 Trigger, 1 EEP)       //
  ///////////////////////////////////////////////////////////

	assign trig_ss_n = (ss == 3'b000) ? spi_SS_n : 1'b1;
	assign ch1_ss_n = (ss == 3'b001) ? spi_SS_n : 1'b1;
	assign ch2_ss_n = (ss == 3'b010) ? spi_SS_n : 1'b1;
	assign ch3_ss_n = (ss == 3'b011) ? spi_SS_n : 1'b1;
	assign EEP_ss_n = (ss == 3'b100) ? spi_SS_n : 1'b1;
  
  ///////////////////////////////////
  // Instantiate UART_comm module //
  /////////////////////////////////
	UART_comm iUART_c(.clk(clk), .rst_n(rst_n), .clr_cmd_rdy(clr_cmd_rdy), .trmt(send_resp),
					.tx_data(tx_data), .RX(RX), .cmd_rdy(cmd_rdy), .cmd(cmd), .tx_done(tx_done), .TX(TX));

  ///////////////////////////
  // Instantiate dig_core //
  /////////////////////////
	dig_core iDC(.clk(clk), .rst_n(rst_n), .adc_clk(adc_clk), .trig1(trig1), .trig2(trig2),
					.SPI_data(SPI_data), .wrt_SPI(wrt_SPI), .SPI_done(SPI_done), .ss(ss),
					.EEP_data(EEP_data), .rclk(rclk), .en(en), .we(we), .addr(addr), 
					.ch1_rdata(ch1_rdata), .ch2_rdata(ch2_rdata), .ch3_rdata(ch3_rdata), .cmd(cmd),
					.cmd_rdy(cmd_rdy), .clr_cmd_rdy(clr_cmd_rdy), .resp_data(resp_data),
					.send_resp(send_resp), .resp_sent(resp_sent));

  //////////////////////////////////////////////////////////////
  // Instantiate the 3 512 RAM blocks that store A2D samples //
  ////////////////////////////////////////////////////////////
  RAM512 iRAM1(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch1_data),.rdata(ch1_rdata));
  RAM512 iRAM2(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch2_data),.rdata(ch2_rdata));
  RAM512 iRAM3(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch3_data),.rdata(ch3_rdata));

endmodule
  