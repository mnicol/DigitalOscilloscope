module UART_Tranceiver (rdy, rx_data, clr_rdy, RX, trmt, tx_data, tx_done, TX, clk, rst_n);

input clr_rdy, trmt, RX, clk, rst_n;
input [7:0] tx_data;

output rdy, TX, tx_done;
output [7:0]rx_data;

UART_tx TXDATA(.clk(clk), .rst_n(rst_n), .tx_data(tx_data), .trmt(trmt), .TX(TX), .tx_done(tx_done));

UART_rx RXDATA(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_rdy), .rx_data(rx_data), .rdy(rdy));


endmodule
