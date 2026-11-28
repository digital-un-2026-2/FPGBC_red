`timescale 1ns/1ps
module captura;
  initial begin
    $dumpfile("sala.vcd");
    $dumpvars(0, tb_sala);
  end
endmodule
