`timescale 1ns/1ps

// ============================================================
// MODULO 1: TRANSMISOR Y RECEPTOR SERIAL (32 BITS CONTINUOS)
// TX: transmite bit a bit en flanco de subida (MSB primero).
// RX: captura bit a bit en flanco de bajada y hace corrimiento.
// ============================================================

module serial_endpoint (
    input wire clk,
    input wire cs,

    input wire rx,
    output wire tx,

    input wire [31:0] tx_data,
    output reg [31:0] rx_data,

    output reg data_valid,

    // Senales de observacion para GTKWave
    output reg [4:0] bit_count,
    output reg [31:0] tx_complete_word, // Palabra completa de 32 bits cargada para transmitir
    output wire [31:0] debug_tx_shift,  // Registro de corrimiento TX en tiempo real
    output wire [31:0] debug_rx_shift   // Registro de corrimiento RX en tiempo real
);

    reg [31:0] tx_shift;
    reg [31:0] rx_shift;

    reg [4:0] tx_bit_count;
    reg tx_active;

    // La salida TX siempre expone el MSB actual del registro de corrimiento
    assign tx = (cs && tx_active) ? tx_shift[31] : 1'b0;

    // Exponer registros internos de corrimiento
    assign debug_tx_shift = tx_shift;
    assign debug_rx_shift = rx_shift;

    // --------------------------------------------------------
    // TRANSMISOR (Flanco de subida)
    // Carga la palabra de 32 bits y la va desplazando bit a bit
    // --------------------------------------------------------
    always @(posedge clk or negedge cs) begin
        if (!cs) begin
            tx_shift         <= 32'b0;
            tx_complete_word <= 32'b0;
            tx_bit_count     <= 5'd0;
            tx_active        <= 1'b0;
        end
        else begin
            if (!tx_active) begin
                // Primer flanco tras activar CS: carga los 32 bits iniciales
                tx_shift         <= tx_data;
                tx_complete_word <= tx_data;
                tx_bit_count     <= 5'd0;
                tx_active        <= 1'b1;
            end
            else if (tx_bit_count == 5'd31) begin
                // Ya salieron los 32 bits: carga la siguiente palabra completa
                tx_shift         <= tx_data;
                tx_complete_word <= tx_data;
                tx_bit_count     <= 5'd0;
            end
            else begin
                // Corrimiento de 1 bit hacia la izquierda
                tx_shift     <= {tx_shift[30:0], 1'b0};
                tx_bit_count <= tx_bit_count + 5'd1;
            end
        end
    end

    // --------------------------------------------------------
    // RECEPTOR (Flanco de bajada)
    // Ingresa cada bit por la derecha y desplaza hacia la izquierda.
    // Al llegar al bit 31 (32 bits recibidos), publica rx_data.
    // --------------------------------------------------------
    always @(negedge clk or negedge cs) begin
        if (!cs) begin
            rx_shift   <= 32'b0;
            rx_data    <= 32'b0;
            bit_count  <= 5'd0;
            data_valid <= 1'b0;
        end
        else if (tx_active) begin
            data_valid <= 1'b0;

            // Corrimiento de 1 bit: entra el nuevo bit por el LSB
            rx_shift <= {rx_shift[30:0], rx};

            if (bit_count == 5'd31) begin
                // Se completaron los 32 corrimientos
                rx_data    <= {rx_shift[30:0], rx};
                data_valid <= 1'b1;
                bit_count  <= 5'd0;
            end
            else begin
                bit_count <= bit_count + 5'd1;
            end
        end
    end

endmodule


// ============================================================
// MODULO 2: BANCO DE PRUEBAS
// ============================================================

module tb_serial_pingpong;

    reg clk;
    reg cs;

    reg [31:0] host_tx_data;
    reg [31:0] guest_tx_data;

    wire host_tx;
    wire guest_tx;

    wire [31:0] host_rx_data;
    wire [31:0] guest_rx_data;

    wire host_valid;
    wire guest_valid;

    wire [4:0] host_bit_count;
    wire [4:0] guest_bit_count;

    // Senales de verificacion completa y corrimiento
    wire [31:0] host_tx_complete;
    wire [31:0] guest_tx_complete;
    wire [31:0] host_tx_shift_mon;
    wire [31:0] host_rx_shift_mon;
    wire [31:0] guest_tx_shift_mon;
    wire [31:0] guest_rx_shift_mon;

    // Reloj de 50 MHz (periodo 20 ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Instancia HOST
    serial_endpoint HOST (
        .clk(clk),
        .cs(cs),
        .tx(host_tx),
        .rx(guest_tx),
        .tx_data(host_tx_data),
        .rx_data(host_rx_data),
        .data_valid(host_valid),
        .bit_count(host_bit_count),
        .tx_complete_word(host_tx_complete),
        .debug_tx_shift(host_tx_shift_mon),
        .debug_rx_shift(host_rx_shift_mon)
    );

    // Instancia GUEST
    serial_endpoint GUEST (
        .clk(clk),
        .cs(cs),
        .tx(guest_tx),
        .rx(host_tx),
        .tx_data(guest_tx_data),
        .rx_data(guest_rx_data),
        .data_valid(guest_valid),
        .bit_count(guest_bit_count),
        .tx_complete_word(guest_tx_complete),
        .debug_tx_shift(guest_tx_shift_mon),
        .debug_rx_shift(guest_rx_shift_mon)
    );

    // Secuencia de simulacion
    initial begin
        cs = 0;
        host_tx_data  = 32'hAABBCCDD;
        guest_tx_data = 32'h11223344;

        #40;
        cs = 1;

        // Esperar dos tramas completas de 32 bits
        #1300;

        // Actualizar datos para las siguientes tramas
        host_tx_data  = 32'h12345678;
        guest_tx_data = 32'h87654321;

        #1300;

        cs = 0;
        #40;
        $finish;
    end

    initial begin
        $dumpfile("comunicacion_serial.vcd");
        $dumpvars(0, tb_serial_pingpong);
    end

endmodule
