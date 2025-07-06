Overview
This project presents a modular hardware architecture for a smart temperature control system implemented on FPGA. The system is designed to interface with a digital temperature sensor via the I²C protocol and make real-time decisions for controlling air conditioning systems.

It is ideal for embedded environments and smart control applications, offering noise immunity, parameterized configuration, and scalable design.

System Architecture
The design is composed of three main hardware modules:

1. I²C Controller

Interfaces with a digital temperature sensor.

Sends read commands and retrieves temperature data (two 8-bit bytes).

Communicates using the I²C protocol.

2. Temperature Control Unit (TCU)

Converts raw temperature data into degrees Celsius.

Compares the result to a reference temperature (25°C).

Uses a configurable noise threshold to reduce false triggers.

Generates a DAC value indicating the degree of temperature deviation.

Controls air conditioning decisions (cooling or heating).

3. TCU Wrapper

Integrates both the I²C Controller and TCU.

Manages internal data flow and external interfacing.

Acts as the top-level module for the FPGA design.

Temperature Conversion Logic
Temperature is calculated as:

Temperature = sensor_out × resolution_of_sensor

This value is compared against a 25°C reference, and if the difference exceeds a noise threshold, control signals are triggered accordingly.

Features
Real-Time Temperature Monitoring

Noise-Immune Decision Logic

Proportional DAC Output Based on Deviation

Modular, Scalable Architecture

FPGA-Friendly RTL Design

I²C Protocol Interface

Applications
Smart Home Temperature Control

Industrial Environmental Monitoring

HVAC Automation Systems

Embedded Control Systems

Tools & Platforms
Design Language: Verilog / VHDL (depending on repo)

Target FPGA Boards: PYNQ Z2, ZCU102 (or similar)

Simulation: ModelSim / Vivado Simulator

Synthesis: Xilinx Vivado
