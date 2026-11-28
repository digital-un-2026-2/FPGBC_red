`timescale 1ns/1ps
// Custom 33-clock transaction: presence flag followed by a 32-bit payload.
module sala_transport(
 input wire clk_sys, rst, input wire [1:0] grant,
 input wire sc_in, data_in, output reg sc_out, output wire sc_oe,
 output wire data_out, data_oe, input wire [31:0] tx_data,
 input wire tx_valid, output wire tx_ready, output reg [31:0] rx_data,
 output reg rx_valid, input wire rx_ready, output reg overflow, frame_loss
);
 wire host = grant==2'b01, guest = grant==2'b10;
 wire enabled = !rst && (host || guest);
 assign sc_oe = !rst && host;
 assign data_oe = enabled;
 // Conservative fixed timing; see README for the permitted clock ratio.
 localparam HALF=24, PAUSE=192, QUAL=64;
 reg [7:0] timer; reg [5:0] pulses; reg gap;
 always @(posedge clk_sys) begin
   if (rst || !host) begin sc_out<=0; timer<=0; pulses<=0; gap<=1; end
   else if (gap) begin
     if (timer==PAUSE-1) begin timer<=0; sc_out<=1; gap<=0; end
     else timer<=timer+1'b1;
   end else if (timer==HALF-1) begin
     timer<=0; sc_out<=!sc_out;
     if (sc_out) begin
       if (pulses==32) begin pulses<=0; gap<=1; end
       else pulses<=pulses+1'b1;
     end
   end else timer<=timer+1'b1;
 end
 // Both ends decode the same timing. Host uses its own registered SC, not
 // pin activity to authorize driving. Data/SC are oversampled, not bus CDC.
 (* ASYNC_REG="TRUE" *) reg [1:0] sc_sync, di_sync;
 reg previous;
 always @(posedge clk_sys) begin
   sc_sync<={sc_sync[0],host ? sc_out : sc_in};
   di_sync<={di_sync[0],data_in}; previous<=sc_sync[1];
 end
 wire rising=sc_sync[1] && !previous, falling=!sc_sync[1] && previous;
 reg [6:0] quiet;
 reg [2:0] state;
 localparam WAIT_GAP=0, ARMED=1, HEADER=2, BODY=3, DONE=4;
 reg full, header_tx, header_rx, show_body;
 reg [31:0] pending, active_word;
 reg core_cs, core_req, core_clk, core_rx;
 wire core_tx, core_valid; wire [31:0] core_word;
 assign tx_ready=enabled && !full;
 assign data_out=show_body ? core_tx : header_tx;
 // Registered, glitch-free local replica. core_rx is registered a whole
 // clk_sys period before core_clk falls; no external SC drives a clock pin.
 always @(posedge clk_sys) core_clk<=core_req;
 serial_endpoint endpoint(.clk(core_clk),.cs(core_cs),.rx(core_rx),.tx(core_tx),
    .tx_data(active_word),.rx_data(core_word),.data_valid(core_valid),
    .bit_count(),.tx_complete_word(),.debug_tx_shift(),.debug_rx_shift());
 always @(posedge clk_sys) begin
   if (!enabled) begin
     state<=WAIT_GAP; quiet<=0; full<=0; pending<=0; active_word<=0;
     rx_valid<=0;rx_data<=0;overflow<=0;frame_loss<=0;
     core_req<=0;core_cs<=0;core_rx<=0;header_tx<=0;header_rx<=0;show_body<=0;
   end else begin
     if(tx_valid && tx_ready) begin pending<=tx_data;full<=1;end
     if(rx_ready) rx_valid<=0;
     if(rising || falling) quiet<=0;
     else if(quiet<QUAL) quiet<=quiet+1'b1;
     if(!rising && !falling && quiet==QUAL-1) begin
       // Low qualifies framing; high can abort but never arms the decoder.
       if(state==HEADER || state==BODY) frame_loss<=1;
       state<=sc_sync[1] ? WAIT_GAP : ARMED;
       core_cs<=0;core_req<=0;show_body<=0;header_tx<=0;
     end else case(state)
       ARMED: if(rising) begin
         header_tx<=full;active_word<=pending;
         if(full) full<=0;
         state<=HEADER;
       end
       HEADER: if(falling) begin header_rx<=di_sync[1];core_cs<=1;state<=BODY;end
       BODY: begin
         if(rising) begin core_req<=1;show_body<=1;end
         if(falling) begin core_rx<=di_sync[1];core_req<=0;end
         if(core_valid) begin
           if(header_rx) begin
             if(rx_valid && !rx_ready) overflow<=1;
             else begin rx_data<=core_word;rx_valid<=1;end
           end
           state<=DONE;
         end
       end
       default: ; // Ignore further edges until a qualified low gap.
     endcase
   end
 end
endmodule
