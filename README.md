# FPGA-Based Secure Data Logging System Using AES-128

FPGA-based secure data logging system using AES-128 encryption, AXI4-Lite, UART communication, password authentication, tamper detection, and performance monitoring.

## Features

- AES-128 encryption
- AXI4-Lite control and data interface
- UART communication
- Password authentication
- Tamper detection
- Tamper LED and buzzer alerts
- AES operation status monitoring
- Performance cycle counter
- SystemVerilog RTL simulation and verification

## AES-128 Test Vector

### Plaintext

```text
00112233445566778899AABBCCDDEEFF
```

### Key

```text
000102030405060708090A0B0C0D0E0F
```

### Expected Ciphertext

```text
69C4E0D86A7B0430D8CDB78070B4C55A
```

## Repository Structure

```text
fpga-aes128-secure-data-logger/
├── rtl/
│   ├── aes_data_path.sv
│   ├── aes_engine.sv
│   └── secure_logger_top.sv
├── sim/
│   └── secure_logger_top_tb.sv
└── README.md
```

## Tools Used

- Xilinx Vivado 2023.2
- Verilog/SystemVerilog
- XSim
- RTL Simulation
- FPGA Synthesis and Implementation

## Verification

The SystemVerilog testbench covers:

- AES encryption
- Password authentication
- Correct and incorrect password cases
- Tamper detection
- UART-related functionality
- System control and status

## Key Learning Outcomes

- RTL design and SystemVerilog
- AES-128 hardware implementation
- AXI4-Lite peripheral integration
- UART communication
- Testbench development
- Waveform debugging
- FPGA synthesis and timing analysis

## Author

**Kaushtav Borkata<PRIVATE_PERSON>**

RTL Design & Verification | FPGA Design
