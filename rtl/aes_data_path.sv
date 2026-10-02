`timescale 1ns / 1ps

module aes_data_path (

    //==========================================================
    // 128-bit plaintext coming from AXI registers
    //==========================================================

    input logic [31:0] aes_data0,
    input logic [31:0] aes_data1,
    input logic [31:0] aes_data2,
    input logic [31:0] aes_data3,

    //==========================================================
    // AES-128 key
    //==========================================================

    input logic [127:0] key,

    //==========================================================
    // 128-bit encrypted result
    //==========================================================

    output logic [127:0] aes_result

);

    //==========================================================
    // Combine four 32-bit words into one 128-bit plaintext
    //==========================================================

    logic [127:0] plaintext;

    assign plaintext = {
        aes_data0,
        aes_data1,
        aes_data2,
        aes_data3
    };


    //==========================================================
    // AES-128 CORE
    //==========================================================

    aes_core u_aes_core (

        .plaintext  (plaintext),
        .key        (key),
        .ciphertext (aes_result)

    );

endmodule