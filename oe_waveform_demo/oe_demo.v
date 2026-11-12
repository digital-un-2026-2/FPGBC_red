`timescale 1ns/1ps

// Modelo conceptual: OE abre/cierra una conexión bidireccional ideal.
// No reproduce los detalles eléctricos internos del TXS0101.
module oe_demo_model (
    input  wire oe,
    input  wire fpga1_tx_en,
    input  wire fpga1_data,
    input  wire fpga2_tx_en,
    input  wire fpga2_data,
    output tri  side_a,
    output tri  side_b
);
    assign side_a = fpga1_tx_en ? fpga1_data : 1'bz;
    assign side_b = fpga2_tx_en ? fpga2_data : 1'bz;

    // OE=1 conecta ambas caras; OE=0 las aísla.
    tranif1 u_oe_switch (side_a, side_b, oe);
endmodule

module tb_oe_demo;
    reg oe = 1'b0;
    reg fpga1_data_ready = 1'b0;
    reg fpga2_data_ready = 1'b0;
    reg fpga1_tx_en = 1'b0;
    reg fpga2_tx_en = 1'b0;
    reg fpga1_data = 1'b0;
    reg fpga2_data = 1'b0;
    reg [3:0] phase = 4'd0;

    wire side_a;
    wire side_b;
    wire both_driving = fpga1_tx_en & fpga2_tx_en;
    wire opposite_values = fpga1_data ^ fpga2_data;
    wire driver_conflict = oe & both_driving & opposite_values;

    oe_demo_model dut (
        .oe(oe),
        .fpga1_tx_en(fpga1_tx_en),
        .fpga1_data(fpga1_data),
        .fpga2_tx_en(fpga2_tx_en),
        .fpga2_data(fpga2_data),
        .side_a(side_a),
        .side_b(side_b)
    );

    initial begin
        $dumpfile("oe_demo.vcd");
        $dumpvars(0, tb_oe_demo);

        // Ambos tienen datos preparados: FPGA1=1 y FPGA2=0.
        // DATA_READY no significa que ya estén autorizadas a transmitir.
        fpga1_data_ready = 1'b1;
        fpga2_data_ready = 1'b1;
        fpga1_data = 1'b1;
        fpga2_data = 1'b0;
        fpga1_tx_en = 1'b1;
        fpga2_tx_en = 1'b1;
        oe = 1'b0;
        phase = 4'd0;
        #10;
        if (side_a !== 1'b1 || side_b !== 1'b0)
            $fatal(1, "OE=0 debe aislar ambos lados: A=1, B=0");
        $display("0-10 ns: OE=0; ambos listos, buses aislados A=%b B=%b", side_a, side_b);

        // Turno FPGA1: solo FPGA1 conduce; el otro lado recibe.
        oe = 1'b1;
        fpga2_tx_en = 1'b0;
        phase = 4'd1;
        #10;
        if (side_a !== 1'b1 || side_b !== 1'b1)
            $fatal(1, "FPGA1->FPGA2 no pasó el dato 1");
        $display("10-20 ns: OE=1; solo FPGA1 transmite; ambos ven 1");

        // Turno FPGA2: FPGA1 libera el bus antes del cambio de sentido.
        fpga1_tx_en = 1'b0;
        fpga2_tx_en = 1'b1;
        phase = 4'd2;
        #10;
        if (side_a !== 1'b0 || side_b !== 1'b0)
            $fatal(1, "FPGA2->FPGA1 no pasó el dato 0");
        $display("20-30 ns: OE=1; solo FPGA2 transmite; ambos ven 0");

        // Ambos conducen el mismo valor: no aparece X, pero OE no arbitra.
        fpga1_tx_en = 1'b1;
        fpga1_data = 1'b1;
        fpga2_data = 1'b1;
        phase = 4'd3;
        #10;
        if (side_a !== 1'b1 || side_b !== 1'b1 || !both_driving)
            $fatal(1, "La fase de dos conductores iguales no se representó");
        $display("30-40 ns: OE=1; ambos conducen 1; la forma de onda no muestra X");

        // Ambos conducen valores opuestos: la red digital se resuelve a X.
        fpga2_data = 1'b0;
        phase = 4'd4;
        #10;
        if (side_a !== 1'bx || side_b !== 1'bx || !driver_conflict)
            $fatal(1, "Se esperaba X por dos conductores opuestos con OE=1");
        $display("40-50 ns: OE=1; FPGA1=1 y FPGA2=0; bus=%b (conflicto)", side_a);

        // OE bajo vuelve a separar las redes locales.
        oe = 1'b0;
        phase = 4'd5;
        #10;
        if (side_a !== 1'b1 || side_b !== 1'b0)
            $fatal(1, "OE=0 debe volver a aislar los valores locales");
        $display("50-60 ns: OE=0; A vuelve a 1 y B a 0, aislados");

        // Sin transmisores, ambos lados quedan en alta impedancia.
        fpga1_tx_en = 1'b0;
        fpga2_tx_en = 1'b0;
        phase = 4'd6;
        #10;
        if (side_a !== 1'bz || side_b !== 1'bz)
            $fatal(1, "Con ambos transmisores apagados, se esperaba Z");
        $display("60-70 ns: ambos TX liberan sus líneas: A=Z B=Z");

        $display("PASS: OE habilita/aisla; no selecciona quién transmite.");
        $finish;
    end
endmodule
