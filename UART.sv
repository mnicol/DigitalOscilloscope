module UART(clk, rst_n, tx_data, trmt, TX, tx_done, RX, clr_rdy, rx_data, rdy);

input clk, rst_n, trmt, RX, clr_rdy;
input reg [7:0] tx_data;
output reg TX, tx_done, rdy;
output reg [7:0] rx_data;

UART_tx UART_tx(.clk(clk), .rst_n(rst_n), .tx_data(tx_data), 
								.trmt(trmt), .TX(TX), .tx_done(tx_done));

UART_rcv UART_rcv(.clk(clk), .rst_n(rst_n), .RX(RX), 
								.clr_rdy(clr_rdy), .rx_data(rx_data), .rdy(rdy));

endmodule
