`timescale 1ns / 1ps

module secure_logger_top #(
    parameter integer UART_CLKS_PER_BIT = 7937
)(
    input  logic clk,
    input  logic resetn,

    // =========================================================
    // AXI4-Lite interface
    // =========================================================

    input  logic [6:0]  s_axi_awaddr,
    input  logic [2:0]  s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [6:0]  s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // =========================================================
    // Security inputs
    // =========================================================

    input  logic dip_tamper,
    input  logic vibration_tamper,

    // =========================================================
    // UART
    // =========================================================

    input  logic uart_rx,
    output logic uart_tx,

    // =========================================================
    // Security outputs
    // =========================================================

    output logic tamper_led,
    output logic buzzer
);


    // =========================================================
    // AES / CRC signals
    // =========================================================

    logic [127:0] aes_data;
    logic [127:0] aes_key;
    logic [127:0] aes_result;

    logic aes_start;
    logic axi_aes_start;
    logic uart_aes_start;
    logic aes_start_to_engine;

    logic aes_busy;
    logic aes_done;

    logic [31:0] aes_cycle_count;
    logic [31:0] crc_result;


    // =========================================================
    // Tamper / security signals
    // =========================================================

    logic tamper_detected;
    logic tamper_event;

    logic password_valid;
    logic password_valid_auth;
    logic system_locked;
    logic system_unlocked;

    logic security_reset;


    // =========================================================
    // UART TX signals from AXI
    // =========================================================

    logic uart_start;
    logic [7:0] uart_data;

    logic uart_busy;
    logic uart_done;


    // =========================================================
    // UART RX signals
    // =========================================================

    logic [7:0] rx_data;
    logic rx_valid;


    // =========================================================
    // Password signals
    // =========================================================

    logic [7:0] entered_password;
    logic password_ready;


    // =========================================================
    // UART command signals
    // =========================================================

    logic cmd_help;
    logic cmd_status;
    logic cmd_aes;
    logic cmd_reset;


    // =========================================================
    // UART command-control signals
    // =========================================================

    logic uart_cmd_start;
    logic [7:0] uart_cmd_data;


    // =========================================================
    // UART TX arbitration signals
    // =========================================================

    logic uart_tx_start_mux;
    logic [7:0] uart_tx_data_mux;


    // =========================================================
    // 1. TAMPER DETECTION
    // =========================================================

    tamper_detector u_tamper_detector (
        .dip_tamper       (dip_tamper),
        .vibration_tamper (vibration_tamper),
        .tamper_detected  (tamper_detected)
    );


    // =========================================================
    // 2. TAMPER EVENT LATCH
    // =========================================================

    tamper_event_latch u_tamper_event_latch (
        .clk            (clk),
        .resetn         (resetn),
        .tamper_detected(tamper_detected),
        .tamper_event   (tamper_event)
    );


    // =========================================================
    // 3. SECURITY CONTROLLER
    //
    // security_reset allows the UART R command to perform
    // a logical security recovery.
    // =========================================================

    security_controller u_security_controller (
        .clk            (clk),
        .reset          (~resetn | security_reset),
        .tamper_detected(tamper_detected),
        .password_valid (password_valid),
        .system_locked  (system_locked),
        .system_unlocked(system_unlocked)
    );


    // =========================================================
    // 4. SECURITY ALERT
    // =========================================================

    security_alert u_security_alert (
        .system_locked(system_locked),
        .tamper_led    (tamper_led),
        .buzzer        (buzzer)
    );


    // =========================================================
    // 5. UART RECEIVER
    // =========================================================

    uart_rx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) u_uart_rx (
        .clk     (clk),
        .resetn  (resetn),
        .rx      (uart_rx),
        .rx_data (rx_data),
        .rx_valid(rx_valid)
    );


    // =========================================================
    // 6. PASSWORD INPUT
    // =========================================================

    password_input u_password_input (
        .clk             (clk),
        .reset           (~resetn),
        .rx_data         (rx_data),
        .rx_valid        (rx_valid),
        .entered_password(entered_password),
        .password_ready  (password_ready)
    );


    // =========================================================
    // 7. PASSWORD AUTHENTICATION
    // =========================================================

    password_auth u_password_auth (
        .entered_password(entered_password),
        .password_valid  (password_valid_auth)
    );


    // =========================================================
    // Password validity is accepted only when a new password
    // has actually been received.
    //
    // This prevents an old correct password from remaining
    // permanently valid.
    // =========================================================

    assign password_valid = password_valid_auth & password_ready;


    // =========================================================
    // 8. UART COMMAND HANDLER
    //
    // H = Help
    // S = Status
    // A = AES
    // R = Reset
    // =========================================================

    uart_command_handler u_uart_command_handler (
        .clk       (clk),
        .reset     (~resetn),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),

        .cmd_help  (cmd_help),
        .cmd_status(cmd_status),
        .cmd_aes   (cmd_aes),
        .cmd_reset (cmd_reset)
    );


    // =========================================================
    // 9. UART COMMAND CONTROL / ARBITRATION
    // =========================================================

    uart_command_control u_uart_command_control (
        .clk            (clk),
        .reset          (~resetn),

        .cmd_help       (cmd_help),
        .cmd_status     (cmd_status),
        .cmd_aes        (cmd_aes),
        .cmd_reset      (cmd_reset),

        .system_locked  (system_locked),
        .system_unlocked(system_unlocked),
        .tamper_detected(tamper_detected),

        .aes_busy       (aes_busy),
        .aes_done       (aes_done),

        .axi_aes_start  (axi_aes_start),

        .uart_busy      (uart_busy),

        .uart_cmd_start (uart_cmd_start),
        .uart_cmd_data  (uart_cmd_data),

        .uart_aes_start (uart_aes_start),
        .security_reset (security_reset)
    );


    // =========================================================
    // 10. AES START ARBITRATION
    //
    // AES can be requested by either:
    //
    //      AXI  -> axi_aes_start
    //      UART -> uart_aes_start
    //
    // The AES engine receives only one combined request.
    //
    // AES cannot be started while the system is locked.
    // =========================================================

    assign aes_start_to_engine =
        !system_locked &&
        !aes_busy &&
        (axi_aes_start || uart_aes_start);


    // =========================================================
    // 11. AES ENGINE
    // =========================================================

    aes_core u_aes_engine (
    .clk         (clk),
    .rst_n       (resetn),
    .start       (aes_start_to_engine),
    .plaintext   (aes_data),
    .key         (aes_key),
    .ciphertext  (aes_result),
    .busy        (aes_busy),
    .done        (aes_done),
    .cycle_count (aes_cycle_count)
);

    // =========================================================
    // 12. CRC32
    // =========================================================

    crc32 u_crc32 (
        .data_in(aes_data),
        .crc_out(crc_result)
    );


    // =========================================================
    // 13. AXI4-LITE SECURE LOGGER
    //
    // AXI remains the processor/software interface.
    // =========================================================

    custom_axi4lite_v1_0_S00_AXI u_axi (
        .S_AXI_ACLK   (clk),
        .S_AXI_ARESETN(resetn),

        .S_AXI_AWADDR (s_axi_awaddr),
        .S_AXI_AWPROT (s_axi_awprot),
        .S_AXI_AWVALID(s_axi_awvalid),
        .S_AXI_AWREADY(s_axi_awready),

        .S_AXI_WDATA  (s_axi_wdata),
        .S_AXI_WSTRB  (s_axi_wstrb),
        .S_AXI_WVALID (s_axi_wvalid),
        .S_AXI_WREADY (s_axi_wready),

        .S_AXI_BRESP  (s_axi_bresp),
        .S_AXI_BVALID (s_axi_bvalid),
        .S_AXI_BREADY (s_axi_bready),

        .S_AXI_ARADDR (s_axi_araddr),
        .S_AXI_ARPROT (s_axi_arprot),
        .S_AXI_ARVALID(s_axi_arvalid),
        .S_AXI_ARREADY(s_axi_arready),

        .S_AXI_RDATA  (s_axi_rdata),
        .S_AXI_RRESP  (s_axi_rresp),
        .S_AXI_RVALID (s_axi_rvalid),
        .S_AXI_RREADY (s_axi_rready),

        // AES interface
        .aes_data     (aes_data),
        .aes_key      (aes_key),
        .aes_start    (axi_aes_start),
        .aes_busy     (aes_busy),
        .aes_done     (aes_done),
        .aes_cycle_count(aes_cycle_count),
        .aes_result   (aes_result),

        // CRC
        .crc_result   (crc_result),

        // Security
        .tamper_detected(tamper_detected),
        .tamper_event   (tamper_event),

        // UART TX requested through AXI
        .uart_data    (uart_data),
        .uart_start   (uart_start),
        .uart_busy    (uart_busy),
        .uart_done    (uart_done)
    );


    // =========================================================
    // 14. UART TX ARBITRATION
    //
    // AXI and UART command control share ONE physical UART TX.
    //
    // UART command response gets priority when requested.
    // =========================================================

    assign uart_tx_start_mux =
        uart_cmd_start | uart_start;

    assign uart_tx_data_mux =
        uart_cmd_start ? uart_cmd_data : uart_data;


    // =========================================================
    // 15. UART TRANSMITTER
    // =========================================================

    uart_tx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) u_uart_tx (
        .clk     (clk),
        .resetn  (resetn),

        .tx_start(uart_tx_start_mux),
        .tx_data (uart_tx_data_mux),

        .tx      (uart_tx),
        .tx_busy (uart_busy),
        .tx_done (uart_done)
    );

endmodule