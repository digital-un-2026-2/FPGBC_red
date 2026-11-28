`timescale 1ns/1ps
module tb_sala #(parameter CB_HALF=6);
reg ca=0, cb=0; always #5 ca=~ca; initial begin #1; forever #(CB_HALF) cb=~cb; end
reg ra=1,rb=1; reg [1:0] ga=0,gb=0;
reg va=0,vb=0,pa=0,pb=0; reg [31:0] da,db;
wire oa,ob,sa,sb,xa,xb,ta,tb,qa,qb,fa,fb,ea,eb,la,lb;
wire [31:0] ya,yb;
reg isolate=0,fake=0;
wire sc=oa?sa:ob?sb:0;
wire #7 remote_sc=sc; wire #13 a_rx=xb; wire #9 b_rx=xa;
sala_transport A(ca,ra,ga,remote_sc,a_rx,sa,oa,xa,ta,da,va,qa,ya,fa,pa,ea,la);
sala_transport B(cb,rb,gb,isolate?fake:remote_sc,b_rx,sb,ob,xb,tb,db,vb,qb,yb,fb,pb,eb,lb);
// Independent wire decoder for first two bursts, no peeking into either DUT.
integer i; reg [32:0] wire_a,wire_b; time last_edge;
initial begin
 wait(oa); @(posedge sc);
 for(i=0;i<33;i=i+1) begin
   if(i!=0) @(posedge sc);
   last_edge=$time; @(negedge sc);
   if($time-last_edge!=240) $fatal(1,"wrong SC high period");
   wire_a={wire_a[31:0],xa};wire_b={wire_b[31:0],xb};
 end
 if(wire_a!==33'h180000001 || wire_b!==33'h176543210) $fatal(1,"wrong wire format");
 last_edge=$time; @(posedge sc); if($time-last_edge!=1920) $fatal(1,"wrong frame gap");
 $display("PASS wire header, 32 bits MSB first, SC high time and frame gap");
end
always @(posedge ca or posedge cb) if(oa && ob) $fatal(1,"SC contention");
task put_a(input [31:0] w); begin @(negedge ca); while(!qa) @(negedge ca); da=w; va=1; @(negedge ca);va=0; da=~w;end endtask
task put_b(input [31:0] w); begin @(negedge cb); while(!qb) @(negedge cb); db=w; vb=1; @(negedge cb);vb=0; db=~w;end endtask
task get_a(input [31:0] w); begin wait(fa); @(negedge ca); if(ya!==w) $fatal(1,"A received %h expected %h",ya,w);pa=1;@(negedge ca);pa=0;end endtask
task get_b(input [31:0] w); begin wait(fb); @(negedge cb); if(yb!==w) $fatal(1,"B received %h expected %h",yb,w);pb=1;@(negedge cb);pb=0;end endtask
initial begin
 #94; ra=0;rb=0; #100;
 if({oa,ob,ta,tb}!==0) $fatal(1,"ungranted drivers");
 @(negedge cb);gb=2; @(negedge ca);ga=1;
 fork put_a(32'h80000001);put_b(32'h76543210);join
 fork get_b(32'h80000001);get_a(32'h76543210);join
 $display("PASS full duplex, independent clocks");
 // Keep A's mailbox occupied across another delivery; drop newest only.
 put_b(32'h0); wait(fa); if(ya!==0) $fatal(1,"zero not payload");
 put_b(32'hffffffff); wait(ea); get_a(0);
 repeat(70) @(posedge sc); if(fa || fb) $fatal(1,"empty polls delivered");
 $display("PASS zero, empty polls, sticky overflow, oldest preserved");
 // Cut B's input while a payload is in flight. Its outgoing queue is
 // consumed at start, not retried. Hold level high long enough to abort.
 put_a(32'h12345678); wait(!qa); wait(qa); repeat(7) @(posedge sc);
 fake=1;isolate=1;repeat(150) @(negedge cb);
 if(!lb || fb || ob) $fatal(1,"stopped-high recovery");
 // A few false clocks without a low delimiter cannot align the guest.
 repeat(6) begin #230 fake=0; #230 fake=1;end
 if(fb || ob) $fatal(1,"unframed edges published data");
 // Reconnect low inside the long inter-frame pause; send again explicitly.
 @(negedge ca);ga=0;fake=0;repeat(120) @(negedge cb);isolate=0;
 @(negedge ca);ga=1;put_a(32'hdeadbeef);get_b(32'hdeadbeef);
 // Force a qualified LOW in the middle of a word, with loss flag cleared.
 @(negedge cb);rb=1;repeat(5) @(negedge cb);rb=0;
 repeat(2) @(posedge sc); // finish the preceding transaction/gap naturally
 repeat(34) @(posedge sc); // at least one qualified gap has occurred
 put_a(32'h33333333);wait(qa);repeat(5) @(posedge sc);@(negedge sc);
 fake=0;isolate=1;repeat(160) @(negedge cb);
 if(!lb || fb || ob) $fatal(1,"stopped-low partial published or takeover");
 @(negedge ca);ga=0; repeat(5) @(negedge ca);isolate=0;
 @(negedge ca);ga=1;put_a(32'h9f00000b);get_b(32'h9f00000b);
 $display("PASS stopped high/low, partial discarded, aligned at next gap");
 // Reset only the guest mid-word: no stale word; next frame re-aligns.
 put_a(32'h11111111);wait(qa);repeat(8) @(posedge sc);
 @(negedge cb);rb=1;repeat(8) @(negedge cb);rb=0;
 put_a(32'h80800001);get_b(32'h80800001);
 if(lb || eb) $fatal(1,"session flags after reset");
 // Both ends released before committing opposite roles. Also fail closed
 // for invalid local encoding, NOT a solution for two legal host grants.
 @(negedge ca);ga=0;@(negedge cb);gb=3;#1000;
 if({oa,ob,ta,tb}!==0) $fatal(1,"invalid grant or release drove pins");
 @(negedge ca);ga=2;repeat(200) @(negedge ca);
 if(oa || fa || ea) $fatal(1,"silence elected guest or stale state");
 put_a(32'hffffffff);repeat(20) @(negedge ca);
 if(qa) $fatal(1,"queued TX not backpressured without clock");
 @(negedge cb);gb=1;put_b(32'h1);
 fork get_b(32'hffffffff);get_a(32'h1);join
 if(oa || !ob || !ta || !tb) $fatal(1,"reverse ownership");
 $display("PASS peer reset, backpressure, role reversal, legal grants never contend"); $finish;
end
initial #2000000 $fatal(1,"timeout");
endmodule
