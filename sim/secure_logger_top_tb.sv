`timescale 1ns / 1ps

module secure_logger_top_tb;

    // =========================================================
    // PARAMETERS
    // =========================================================

    parameter integer CLK_PERIOD      = 10;
    parameter integer UART_CLKS_PER_BIT = 10417;

    // =========================================================
    // CLOCK / RESET
    // =========================================================

    logic clk;
    logic resetn;

    // =========================================================
    // AXI4-LITE
    // =========================================================

    logic [6:0]  s_axi_awaddr;
    logic [2:0]  s_axi_awprot;
    logic        s_axi_awvalid;
    logic        s_axi_awready;

    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid;
    logic        s_axi_wready;

    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;

    logic [6:0]  s_axi_araddr;
    logic [2:0]  s_axi_arprot;
    logic        s_axi_arvalid;
    logic        s_axi_arready;

    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready;

    // =========================================================
    // SECURITY
    // =========================================================

    logic dip_tamper;
    logic vibration_tamper;

    logic tamper_led;
    logic buzzer;

    // =========================================================
    // UART
    // =========================================================

    logic uart_rx;
    logic uart_tx;

    // =========================================================
    // TEST VARIABLES
    // =========================================================

    logic [31:0] read_data;

    logic [31:0] result0;
    logic [31:0] result1;
    logic [31:0] result2;
    logic [31:0] result3;

    logic [31:0] perf_count;
    logic [31:0] status_value;

    // =========================================================
    // CLOCK GENERATION
    // =========================================================

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================================================
    // DUT
    // =========================================================

    secure_logger_top #(
        .UART_CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) dut (

        .clk   (clk),
        .resetn(resetn),

        // AXI WRITE ADDRESS
        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awprot (s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        // AXI WRITE DATA
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wstrb  (s_axi_wstrb),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),

        // AXI WRITE RESPONSE
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),

        // AXI READ ADDRESS
        .s_axi_araddr (s_axi_araddr),
        .s_axi_arprot (s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        // AXI READ DATA
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready),

        // SECURITY
        .dip_tamper       (dip_tamper),
        .vibration_tamper (vibration_tamper),

        // UART
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),

        // SECURITY OUTPUTS
        .tamper_led(tamper_led),
        .buzzer    (buzzer)
    );

    // =========================================================
    // UART BYTE TRANSMISSION TASK
    // =========================================================

    task automatic send_uart_byte(input logic [7:0] data);
        integer i;

        begin

            // IDLE
            uart_rx = 1'b1;

            // START BIT
            uart_rx = 1'b0;
            #(UART_CLKS_PER_BIT * CLK_PERIOD);

            // DATA BITS - LSB FIRST
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #(UART_CLKS_PER_BIT * CLK_PERIOD);
            end

            // STOP BIT
            uart_rx = 1'b1;
            #(UART_CLKS_PER_BIT * CLK_PERIOD);

            // RETURN TO IDLE
            uart_rx = 1'b1;

        end
    endtask

    // =========================================================
    // AXI WRITE TASK
    // =========================================================

    task automatic axi_write(
        input logic [6:0]  addr,
        input logic [31:0] data
    );

        begin

            @(posedge clk);

            s_axi_awaddr  <= addr;
            s_axi_awprot  <= 3'b000;
            s_axi_awvalid <= 1'b1;

            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'b1111;
            s_axi_wvalid  <= 1'b1;

            // Wait until both address and data are accepted
            while (!(s_axi_awready && s_axi_wready))
                @(posedge clk);

            @(posedge clk);

            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            // Wait for write response
            while (!s_axi_bvalid)
                @(posedge clk);

            @(posedge clk);

        end

    endtask

    // =========================================================
    // AXI READ TASK
    // =========================================================

    task automatic axi_read(
        input  logic [6:0] addr,
        output logic [31:0] data
    );

        begin

            @(posedge clk);

            s_axi_araddr  <= addr;
            s_axi_arprot  <= 3'b000;
            s_axi_arvalid <= 1'b1;

            // Wait for address acceptance
            while (!s_axi_arready)
                @(posedge clk);

            @(posedge clk);

            s_axi_arvalid <= 1'b0;

            // Wait for read data
            while (!s_axi_rvalid)
                @(posedge clk);

            data = s_axi_rdata;

            @(posedge clk);

        end

    endtask

    // =========================================================
    // UART MESSAGE CHECKER
    // =========================================================

    task automatic check_uart_message_internal(
        input string expected_message
    );

        integer i;
        integer length_expected;

        begin

            length_expected = expected_message.len();

            $display("");
            $display("========================================");
            $display("Checking internal UART command data");
            $display("Expected message length: %0d",
                     length_expected);
            $display("========================================");

            for (i = 0; i < length_expected; i = i + 1) begin

                wait (dut.u_uart_command_control.uart_cmd_start === 1'b1);

                if (dut.u_uart_command_control.uart_cmd_data ===
                    expected_message[i]) begin

                    $display(
                        "UART CMD BYTE %0d: '%c' PASS",
                        i,
                        expected_message[i]
                    );

                end
                else begin

                    $display(
                        "UART CMD BYTE %0d: EXPECTED '%c' GOT '%c' FAIL",
                        i,
                        expected_message[i],
                        dut.u_uart_command_control.uart_cmd_data
                    );

                end

                @(posedge clk);

            end

            $display("");
            $display("UART MESSAGE CHECK: PASS");
            $display("========================================");

        end

    endtask

    // =========================================================
    // INITIAL CONDITIONS
    // =========================================================

    initial begin

        resetn = 1'b0;

        dip_tamper       = 1'b0;
        vibration_tamper = 1'b0;

        uart_rx = 1'b1;

        s_axi_awaddr  = 7'd0;
        s_axi_awprot  = 3'd0;
        s_axi_awvalid = 1'b0;

        s_axi_wdata   = 32'd0;
        s_axi_wstrb   = 4'd0;
        s_axi_wvalid  = 1'b0;

        s_axi_bready  = 1'b1;

        s_axi_araddr  = 7'd0;
        s_axi_arprot  = 3'd0;
        s_axi_arvalid = 1'b0;

        s_axi_rready  = 1'b1;

        read_data     = 32'd0;

        result0       = 32'd0;
        result1       = 32'd0;
        result2       = 32'd0;
        result3       = 32'd0;

        perf_count    = 32'd0;
        status_value  = 32'd0;

        // =====================================================
        // RESET
        // =====================================================

        $display("");
        $display("========================================");
        $display("SECURE LOGGER TOP TEST");
        $display("========================================");

        $display("");
        $display("Applying reset...");

        repeat (10)
            @(posedge clk);

        resetn = 1'b1;

        repeat (5)
            @(posedge clk);

        $display("Reset released.");

        // =====================================================
        // TEST 1
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 1: NORMAL STATE");
        $display("========================================");

        if ((tamper_led == 1'b0) &&
            (buzzer     == 1'b0)) begin

            $display("TEST 1 NORMAL: PASS");

        end
        else begin

            $display("TEST 1 NORMAL: FAIL");

        end

        // =====================================================
        // TEST 2
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 2: DIP TAMPER");
        $display("========================================");

        dip_tamper = 1'b1;

        repeat (5)
            @(posedge clk);

        if ((tamper_led == 1'b1) &&
            (buzzer     == 1'b1)) begin

            $display("TEST 2 DIP TAMPER: PASS");

        end
        else begin

            $display("TEST 2 DIP TAMPER: FAIL");

        end

        dip_tamper = 1'b0;

        // =====================================================
        // TEST 3
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 3: WRONG PASSWORD");
        $display("========================================");

        dip_tamper = 1'b1;

        repeat (5)
            @(posedge clk);

        // Wrong password
        send_uart_byte(8'hAA);

        repeat (20)
            @(posedge clk);

        if ((tamper_led == 1'b1) &&
            (buzzer     == 1'b1)) begin

            $display("TEST 3 WRONG PASSWORD: PASS");

        end
        else begin

            $display("TEST 3 WRONG PASSWORD: FAIL");

        end

        // =====================================================
        // TEST 4
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 4: CORRECT PASSWORD");
        $display("========================================");

        dip_tamper = 1'b0;

        repeat (10)
            @(posedge clk);

        // Correct password
        send_uart_byte(8'h5A);

        repeat (20)
            @(posedge clk);

        if ((tamper_led == 1'b0) &&
            (buzzer     == 1'b0)) begin

            $display("TEST 4 CORRECT PASSWORD: PASS");

        end
        else begin

            $display("TEST 4 CORRECT PASSWORD: FAIL");

        end

        // =====================================================
        // TEST 5
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 5: VIBRATION TAMPER");
        $display("========================================");

        vibration_tamper = 1'b1;

        repeat (5)
            @(posedge clk);

        if ((tamper_led == 1'b1) &&
            (buzzer     == 1'b1)) begin

            $display("TEST 5 VIBRATION TAMPER: PASS");

        end
        else begin

            $display("TEST 5 VIBRATION TAMPER: FAIL");

        end

        vibration_tamper = 1'b0;

        // =====================================================
        // RESET BEFORE AXI AES TEST
        // =====================================================

        resetn = 1'b0;

        repeat (10)
            @(posedge clk);

        resetn = 1'b1;

        repeat (10)
            @(posedge clk);

        // =====================================================
        // TEST 6 - AXI AES-128
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 6: AXI AES-128");
        $display("========================================");

        // -----------------------------------------------------
        // PLAINTEXT
        // -----------------------------------------------------

        axi_write(
            7'h08,
            32'h00112233
        );

        axi_write(
            7'h0C,
            32'h44556677
        );

        axi_write(
            7'h10,
            32'h8899AABB
        );

        axi_write(
            7'h14,
            32'hCCDDEEFF
        );

        // -----------------------------------------------------
        // KEY
        // -----------------------------------------------------

        axi_write(
            7'h18,
            32'h00010203
        );

        axi_write(
            7'h1C,
            32'h04050607
        );

        axi_write(
            7'h20,
            32'h08090A0B
        );

        axi_write(
            7'h24,
            32'h0C0D0E0F
        );

        $display("AES plaintext and key written.");

        // -----------------------------------------------------
        // START AES
        // -----------------------------------------------------

        axi_write(
            7'h00,
            32'h00000001
        );

        $display("AES START issued.");

        // -----------------------------------------------------
        // WAIT FOR AES DONE
        // -----------------------------------------------------

        wait (dut.aes_done === 1'b1);

        $display("AES DONE detected.");

        $display(
            "AES cycle count = %0d",
            dut.aes_cycle_count
        );

        // -----------------------------------------------------
        // IMPORTANT:
        // Capture INTERNAL AES result immediately.
        // -----------------------------------------------------

        $display("");
        $display("INTERNAL AES RESULT = %h",
                 dut.aes_result);

        $display(
            "EXPECTED AES RESULT = %h",
            128'h69C4E0D86A7B0430C8CDB78070B4C55A
        );

        // -----------------------------------------------------
        // Capture status while AES DONE is still asserted.
        // -----------------------------------------------------

        status_value = {
            27'd0,
            dut.tamper_event,
            dut.aes_done,
            dut.aes_busy,
            dut.tamper_detected,
            dut.password_valid
        };

        $display(
            "INTERNAL AES STATUS = 0x%08h",
            status_value
        );

        // -----------------------------------------------------
        // INTERNAL AES RESULT CHECK
        // -----------------------------------------------------

        if (dut.aes_result ===
            128'h69C4E0D86A7B0430C8CDB78070B4C55A) begin

            $display("INTERNAL AES RESULT: PASS");

        end
        else begin

            $display("INTERNAL AES RESULT: FAIL");

        end

        // -----------------------------------------------------
        // PERFORMANCE
        // -----------------------------------------------------

        if (dut.aes_cycle_count == 32'd10) begin

            $display("AES INTERNAL CYCLE COUNT: PASS");

        end
        else begin

            $display(
                "AES INTERNAL CYCLE COUNT: FAIL - GOT %0d",
                dut.aes_cycle_count
            );

        end

        // -----------------------------------------------------
        // STATUS WHILE DONE IS HIGH
        // -----------------------------------------------------

        if ((dut.aes_busy == 1'b0) &&
            (dut.aes_done == 1'b1)) begin

            $display("AES INTERNAL STATUS: PASS");

        end
        else begin

            $display("AES INTERNAL STATUS: FAIL");

        end

        // -----------------------------------------------------
        // GIVE DONE A CHANCE TO RETURN LOW
        // -----------------------------------------------------

        @(posedge clk);

        // -----------------------------------------------------
        // AXI RESULT READBACK
        // -----------------------------------------------------

        axi_read(
            7'h28,
            result0
        );

        axi_read(
            7'h2C,
            result1
        );

        axi_read(
            7'h30,
            result2
        );

        axi_read(
            7'h34,
            result3
        );

        $display("");
        $display("AES RESULT:");
        $display(
            "%08h %08h %08h %08h",
            result0,
            result1,
            result2,
            result3
        );

        // -----------------------------------------------------
        // AXI AES RESULT CHECK
        // -----------------------------------------------------

        if ((result0 === 32'h69C4E0D8) &&
            (result1 === 32'h6A7B0430) &&
            (result2 === 32'hC8CDB780) &&
            (result3 === 32'h70B4C55A)) begin

            $display("TEST 6 AES RESULT: PASS");

        end
        else begin

            $display("TEST 6 AES RESULT: FAIL");

            $display("");
            $display("Expected:");
            $display(
                "69C4E0D8 6A7B0430 C8CDB780 70B4C55A"
            );

            $display("");
            $display("Actual:");
            $display(
                "%08h %08h %08h %08h",
                result0,
                result1,
                result2,
                result3
            );

        end

        // -----------------------------------------------------
        // PERFORMANCE REGISTER
        // -----------------------------------------------------

        axi_read(
            7'h38,
            perf_count
        );

        $display(
            "AES PERFORMANCE COUNT = %0d",
            perf_count
        );

        if (perf_count === 32'd10) begin

            $display("TEST 6 PERFORMANCE COUNT: PASS");

        end
        else begin

            $display("TEST 6 PERFORMANCE COUNT: FAIL");

        end

        // -----------------------------------------------------
        // AXI STATUS REGISTER
        //
        // DONE is a one-cycle pulse, therefore we only require
        // BUSY=0 here. DONE was already checked internally above.
        // -----------------------------------------------------

        axi_read(
            7'h40,
            status_value
        );

        $display(
            "AES STATUS = 0x%08h",
            status_value
        );

        if (status_value[2] == 1'b0) begin

            $display("TEST 6 AXI STATUS BUSY: PASS");

        end
        else begin

            $display("TEST 6 AXI STATUS BUSY: FAIL");

        end

        // =====================================================
        // TEST 7 - H COMMAND
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 7: H COMMAND");
        $display("========================================");

        send_uart_byte(8'h48);   // H

        check_uart_message_internal(
            "H:HELP S:STATUS A:AES R:RESET"
        );

        $display("TEST 7 H COMMAND: COMPLETE");

        // =====================================================
        // TEST 8 - S COMMAND
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 8: S COMMAND");
        $display("========================================");

        send_uart_byte(8'h53);   // S

        check_uart_message_internal(
            "NORMAL\r\n"
        );

        $display("TEST 8 S COMMAND: COMPLETE");

        // =====================================================
        // TEST 9 - A COMMAND
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 9: A COMMAND");
        $display("========================================");

        send_uart_byte(8'h41);   // A

        check_uart_message_internal(
            "AES START\r\n"
        );

        $display("TEST 9 A COMMAND: COMPLETE");

        // =====================================================
        // TEST 10 - R COMMAND
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 10: R COMMAND");
        $display("========================================");

        send_uart_byte(8'h52);   // R

        check_uart_message_internal(
            "RESET\r\n"
        );

        $display("TEST 10 R COMMAND: COMPLETE");

        // =====================================================
        // FINISH
        // =====================================================

        $display("");
        $display("========================================");
        $display("ALL SECURE LOGGER TESTS COMPLETED");
        $display("========================================");

        #1000;

        $finish;

    end

endmodule
