module RAM_Interface(rclk, en, we, addr, wdata, rdata);

/////////////////////////////////////////
// 		 Inputs 	                      //
///////////////////////////////////////
input logic rclk, en, we;

input logic [8:0] addr;
input logic [7:0] wdata;

/////////////////////////////////////////
// 		 Outputs 	                      //
///////////////////////////////////////
output logic [7:0] rdata;

endmodule
