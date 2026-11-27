`timescale 1ns/1ps

// ============================================================
// MODULO 1: TRANSCEPTOR SERIAL HALF-DUPLEX ESTRICTO
// - Turno 0 (turn == 0): HOST transmite (mueve TX), GUEST recibe (mueve RX).
// - Turno 1 (turn == 1): GUEST transmite (mueve TX), HOST recibe (mueve RX).
// ============================================================

module serial_half_duplex #(
    parameter IS_HOST = 1
)(
    input wire clk,
    input wire cs,

    inout wire data_line, // Unico cable bidireccional de datos

    input wire [31:0] tx_data,
    output reg [31:0] rx_data,

    output reg data_valid,

    // Contadores separados para ver en GTKWave quien se mueve en cada turno
    output reg [4:0] tx_bit_count,       // Solo cuenta cuando este modulo TRANSMITE
    output reg [4:0] rx_bit_count,       // Solo cuenta cuando este modulo RECIBE
    output reg turn,                     // 0: habla HOST | 1: habla GUEST
    output reg [31:0] tx_complete_word,  // Palabra completa enviada en el turno TX
    output wire [31:0] debug_tx_shift,   // Registro TX (solo se mueve en turno TX)
    output wire [31:0] debug_rx_shift    // Registro RX (solo se mueve en turno RX)
);

    reg [31:0] tx_shift;
    reg [31:0] rx_shift;
    reg active;

    // Permisos estrictos de turno
    wire is_my_tx_turn = (IS_HOST == 1) ? (turn == 1'b0) : (turn == 1'b1);
    wire is_my_rx_turn = (IS_HOST == 1) ? (turn == 1'b1) : (turn == 1'b0);

    // Control triestado: solo maneja la linea cuando es su turno de transmitir
    assign data_line = (cs && active && is_my_tx_turn) ? tx_shift[31] : 1'bz;

    // Salidas de depuracion
    assign debug_tx_shift = tx_shift;
    assign debug_rx_shift = rx_shift;

    // --------------------------------------------------------
    // TRANSMISOR Y CONTROL DE TURNO (Flanco de subida)
    // --------------------------------------------------------
    always @(posedge clk or negedge cs) begin
        if (!cs) begin
            tx_shift         <= 32'b0;
            tx_complete_word <= 32'b0;
            tx_bit_count     <= 5'd0;
            turn             <= 1'b0;
            active           <= 1'b0;
        end
        else begin
            if (!active) begin
                // Inicio de la comunicacion (Turno 0: arranca HOST)
                active       <= 1'b1;
                turn         <= 1'b0;
                tx_bit_count <= 5'd0;

                if (IS_HOST == 1) begin
                    tx_shift         <= tx_data;
                    tx_complete_word <= tx_data;
                end
                else begin
                    tx_shift <= 32'b0; // GUEST espera quieto en Turno 0
                end
            end
            else if (is_my_tx_turn) begin
                // SOLO si es mi turno de transmitir, muevo tx_shift y tx_bit_count
                if (tx_bit_count == 5'd31) begin
                    // Termine mis 32 bits: suelto el bus y cedo el turno
                    tx_bit_count <= 5'd0;
                    tx_shift     <= 32'b0;
                    turn         <= ~turn;
                end
                else begin
                    tx_shift     <= {tx_shift[30:0], 1'b0};
                    tx_bit_count <= tx_bit_count + 5'd1;
                end
            end
            else begin
                // No es mi turno de transmitir: mantengo TX congelado en 0
                tx_bit_count <= 5'd0;
                tx_shift     <= 32'b0;
            end
        end
    end

    // --------------------------------------------------------
    // RECEPTOR (Flanco de bajada)
    // Solo captura y desplaza cuando es el turno del otro extremo.
    // Al recibir los 32 bits, cambia el turno de recepcion.
    // --------------------------------------------------------
    always @(negedge clk or negedge cs) begin
        if (!cs) begin
            rx_shift     <= 32'b0;
            rx_data      <= 32'b0;
            rx_bit_count <= 5'd0;
            data_valid   <= 1'b0;
        end
        else if (active) begin
            data_valid <= 1'b0;

            if (is_my_rx_turn) begin
                // SOLO si es mi turno de recibir, desplazo rx_shift y cuento bits
                rx_shift <= {rx_shift[30:0], data_line};

                if (rx_bit_count == 5'd31) begin
                    rx_data      <= {rx_shift[30:0], data_line};
                    data_valid   <= 1'b1;
                    rx_bit_count <= 5'd0;
                end
                else begin
                    rx_bit_count <= rx_bit_count + 5'd1;
                end
            end
            else begin
                // Estoy transmitiendo: mi receptor esta fisicamente inactivo
                rx_bit_count <= 5'd0;
            end
        end
    end

    // Precarga del dato TX justo cuando el otro extremo termina de transmitir
    // para que este listo en el primer flanco del nuevo turno
    always @(negedge clk or negedge cs) begin
        if (!cs) begin
            // Ya reseteado arriba
        end
        else if (active && is_my_rx_turn && (rx_bit_count == 5'd31)) begin
            // En el siguiente flanco de subida me toca transmitir a mi: cargo tx_data
            tx_shift         <= tx_data;
            tx_complete_word <= tx_data;
        end
    end

endmodule


// ============================================================
// MODULO 2: BANCO DE PRUEBAS HALF-DUPLEX
// ============================================================

module tb_serial_half_duplex;

    reg clk;
    reg cs;
    wire data_line;

    reg [31:0] host_tx_data;
    reg [31:0] guest_tx_data;

    wire [31:0] host_rx_data;
    wire [31:0] guest_rx_data;

    wire host_valid;
    wire guest_valid;

    // Contadores separados TX y RX
    wire [4:0] host_tx_bit_count;
    wire [4:0] host_rx_bit_count;
    wire [4:0] guest_tx_bit_count;
    wire [4:0] guest_rx_bit_count;

    wire host_turn;
    wire guest_turn;
    wire [31:0] host_tx_complete;
    wire [31:0] guest_tx_complete;
    wire [31:0] host_tx_shift_mon;
    wire [31:0] host_rx_shift_mon;
    wire [31:0] guest_tx_shift_mon;
    wire [31:0] guest_rx_shift_mon;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    serial_half_duplex #(.IS_HOST(1)) HOST (
        .clk(clk),
        .cs(cs),
        .data_line(data_line),
        .tx_data(host_tx_data),
        .rx_data(host_rx_data),
        .data_valid(host_valid),
        .tx_bit_count(host_tx_bit_count),
        .rx_bit_count(host_rx_bit_count),
        .turn(host_turn),
        .tx_complete_word(host_tx_complete),
        .debug_tx_shift(host_tx_shift_mon),
        .debug_rx_shift(host_rx_shift_mon)
    );

    serial_half_duplex #(.IS_HOST(0)) GUEST (
        .clk(clk),
        .cs(cs),
        .data_line(data_line),
        .tx_data(guest_tx_data),
        .rx_data(guest_rx_data),
        .data_valid(guest_valid),
        .tx_bit_count(guest_tx_bit_count),
        .rx_bit_count(guest_rx_bit_count),
        .turn(guest_turn),
        .tx_complete_word(guest_tx_complete),
        .debug_tx_shift(guest_tx_shift_mon),
        .debug_rx_shift(guest_rx_shift_mon)
    );

    initial begin
        cs = 0;
        host_tx_data  = 32'hAABBCCDD;
        guest_tx_data = 32'h11223344;

        #40;
        cs = 1;

        // Dos intercambios completos (64 ciclos * 20 ns * 2 = 2560 ns + margen)
        #2600;

        host_tx_data  = 32'h12345678;
        guest_tx_data = 32'h87654321;

        #2600;

        cs = 0;
        #40;
        $finish;
    end

    initial begin
        $dumpfile("comunicacion_half_duplex.vcd");
        $dumpvars(0, tb_serial_half_duplex);
    end

endmodule
