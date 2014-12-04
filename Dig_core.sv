module Dig_core(clk, rst_n, adc_clk, trig1, trig2, SPI_data, wrt_SPI, ss, SPI_done, EEP_data, rclk,
		 en, we, addr, chX_rdata, cmd, cmd_rdy, clr_cmd_rdy, resp_data, send_resp, resp_sent);

/////////////////////////////////////////
// 		 Inputs 	                      //
///////////////////////////////////////
input logic clk, rst_n, trig1, trig2, SPI_done, cmd_rdy, resp_sent;

input logic [7:0] EEP_data, chX_rdata;
input logic [23:0] cmd;

/////////////////////////////////////////
// 		 Outputs 	                      //
///////////////////////////////////////
output logic adc_clk, wrt_SPI, rclk, en, we, clr_cmd_rdy, send_resp;

output logic [2:0] ss;
output logic [7:0] resp_data;
output logic [8:0] addr;
output logic [15:0] SPI_data;


Cmd_Config CC(.clk(clk), .rst_n(rst_n), .SPI_data(SPI_data), .wrt_SPI(wrt_SPI), .ss(ss), 
			.SPI_done(SPI_done), .EEP_data(EEP_data), .cmd(cmd), .cmd_rdy(cmd_rdy), 
			.clr_cmd_rdy(clr_cmd_rdy), .restp_data(resp_data), .send_resp(send_resp), .resp_sent(resp_sent));


Data_Capture DC(.trig1(trig1), .trig2(trig2), .rclk(rclk), .en(en), .we(we), .addr(addr));


RAM_Interface RI(.rclk(rclk), .en(en), .we(we), .addr(addr), .wdata(chX_rdata), .rdata(rdata));

endmodule
