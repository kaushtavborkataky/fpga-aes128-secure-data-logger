`timescale 1ns / 1ps

module aes_engine (
    input  logic         clk,
    input  logic         resetn,
    input  logic         start,

    input  logic [127:0] plaintext,
    input  logic [127:0] key,

    output logic [127:0] ciphertext,
    output logic         busy,
    output logic         done,
    output logic [31:0]  cycle_count
);

    // =========================================================
    // AES ROUND KEYS
    // =========================================================

    logic [127:0] round_keys [0:10];

    aes_key_expand u_key_expand (
        .key        (key),
        .round_keys (round_keys)
    );


    // =========================================================
    // STATE REGISTER
    // This register stores the result between AES rounds.
    // =========================================================

    logic [127:0] state_reg;


    // =========================================================
    // ROUND COUNTER
    // Selects which AES round is currently being processed.
    //
    // 1 = Round 1
    // 2 = Round 2
    // ...
    // 9 = Round 9
    // 10 = Final Round
    // =========================================================

    logic [3:0] round_counter;


    // =========================================================
    // COMBINATIONAL AES LOGIC
    // =========================================================

    logic [127:0] initial_state;
    logic [127:0] round_state;
    logic [127:0] final_state;


    // Initial AddRoundKey
    aes_add_round_key u_initial_add_key (
        .state_in  (plaintext),
        .round_key (round_keys[0]),
        .state_out (initial_state)
    );


    // Normal AES round
    aes_round u_round (
        .state_in  (state_reg),
        .round_key (round_keys[round_counter]),
        .state_out (round_state)
    );


    // Final AES round
    aes_final_round u_final_round (
        .state_in  (state_reg),
        .round_key (round_keys[10]),
        .state_out (final_state)
    );


    // =========================================================
    // AES CONTROLLER
    // =========================================================

    always_ff @(posedge clk) begin

        if (!resetn) begin

            state_reg   <= 128'd0;
            ciphertext  <= 128'd0;

            busy        <= 1'b0;
            done        <= 1'b0;

            round_counter <= 4'd0;
            cycle_count   <= 32'd0;

        end

        else begin

            // DONE is normally low
            done <= 1'b0;


            // =================================================
            // START AES
            // =================================================

            if (start && !busy) begin

                // Perform initial AddRoundKey
                state_reg <= initial_state;

                busy <= 1'b1;

                // First AES round will be Round 1
                round_counter <= 4'd1;

                // Start latency measurement
                cycle_count <= 32'd1;

            end


            // =================================================
            // AES IS RUNNING
            // =================================================

            else if (busy) begin

                // Count another clock cycle
                cycle_count <= cycle_count + 32'd1;


                // -------------------------------------------------
                // AES Rounds 1 to 9
                // -------------------------------------------------

                if (round_counter < 10) begin

                    // Store current round result
                    // in the state register.
                    state_reg <= round_state;

                    // Move to next round
                    round_counter <= round_counter + 4'd1;

                end


                // -------------------------------------------------
                // AES FINAL ROUND
                // -------------------------------------------------

                else begin

                    // Store final AES result
                    ciphertext <= final_state;

                    // AES finished
                    busy <= 1'b0;

                    done <= 1'b1;

                end

            end

        end

    end

endmodule