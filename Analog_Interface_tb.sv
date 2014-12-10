module Analog_Interface_tb();

logic clk, adc_clk, rst_n, trig1, trig2, //trig_src, trig_edge, 
									 trig_en, set_cap_done;
logic [7:0] trig_cfg;
logic [8:0] trig_pos;
logic [3:0] decimator;

logic en, we;
logic [8:0] addr, trace_end;

Analog_Interface iAI(.clk(clk), .adc_clk(adc_clk), .rst_n(rst_n), .trig1(trig1), .trig2(trig2), 
							.decimator(decimator), 	.trig_cfg(trig_cfg), .trig_pos(trig_pos), 
							.set_cap_done(set_cap_done), .en(en), .we(we), .addr(addr), .trace_end(trace_end));

parameter clk_period = 2'd2;

///////////////////////////
// Initialize clk				//
/////////////////////////
initial clk = 1;
always #1 clk = !clk;


initial begin
	rst_n = 0;
	trig1 = 0;
	trig2 = 0;
	decimator = 2;
	trig_cfg = 8'b00_0_1_01_00;  // posedge triggered, normal, ch1 source
	trig_pos = 9'h0a1;
	#5 @(posedge clk) rst_n = 1;
	#10 @(posedge iAI.armed) trig1 = 1;
	#(4 * clk_period);
	@(posedge clk) if (iAI.triggered != 1) $display("Error: trigger not set."); else $display("gg1");

	@(posedge set_cap_done) #(6 * clk_period) trig1 = 0;
	trig_pos = 9'h013;
	@(posedge clk) set_cap_done = 1;
	@(posedge clk) set_cap_done = 0;
	@(posedge clk) if (iAI.triggered != 0) $display("Error: trigger still set."); else $display("gg2");

	#10 @(posedge iAI.armed) trig1 = 1;
	#(4 * clk_period);
	@(posedge clk) if (iAI.triggered != 1) $display("Error: trigger not set."); else $display("gg3");

	#10 @(posedge iAI.armed) $stop;
end

endmodule
