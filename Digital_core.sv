/////////////////////////////////////////////////////////////////////////////////
// Digital_core module that implements logic for output signal triggered.     //
// trig_src determines which signal, trig1 or trig2, is setting the trigger, //
// and trig_edge determines if a rising or falling edge of that sig1nal      //
// sets triggered, the trigger event makes trig_set high for 1 clk period, //
// after which triggered goes/stays high until set_cap_done is set.       //
// Triggered can't go high unless armed and trig_en are set              //
//////////////////////////////////////////////////////////////////////////

module Digital_core(input clk, rst_n, trig1, trig2, trig_src, trig_edge, 
										armed, trig_en, set_cap_done, output reg triggered);

logic src_ff1, src_ff2, src_ff3;		// Flip flops for asynchronous trigger inputs
logic trig_w, trig_set, w1, w2, w3;	// Wires for intermediate signals

//////////////////////////////////////////////////////
// MUX logic for trigger source and edge detection //
////////////////////////////////////////////////////
assign trig_w = trig_src ? trig2 : trig1;
assign trig_set = trig_edge ? (~src_ff3 & src_ff2):
															(src_ff3 & ~src_ff2);

//////////////////////////////////////////////
// Flop trig value twice for metastability //
// and once for edge detection            //
///////////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		src_ff1 <= 0;
		src_ff2 <= 0;
		src_ff3 <= 0;
	end
	else begin
		src_ff1 <= trig_w;
		src_ff2 <= src_ff1;
		src_ff3 <= src_ff2;
	end
end

////////////////////////////////////////////////
// Gate logic feedng output signal triggered //
//////////////////////////////////////////////
AND	(w1, trig_set, armed, trig_en);
NOR	(w2, w1, triggered),
		(w3, w2, set_cap_done);

//////////////////////////
// Set triggered value //
////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		triggered <= 0;
	else
		triggered <= w3;
end

endmodule
