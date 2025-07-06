//-----------------------------------------------------------------------------
// Title        : I2C Controller
// Project      : I2C Communication Interface
//-----------------------------------------------------------------------------
// File         : I2C_Controller.sv
// Author       : Saber Mahmoud
// Created      : [Date, dec 2, 2024]
// Last Modified: [Date, dec 2, 2024]
//-----------------------------------------------------------------------------
// Description  : 
//   This module implements an I2C Controller that facilitates communication
//   with I2C-compliant slave devices. It supports standard I2C operations,
//   including Start and Stop conditions, repeated start conditions, 
//   data read/write operations, and acknowledgment handling.
//-----------------------------------------------------------------------------
// Structure: 
//   -IDLE:   Idle cs: waiting for a transaction to start
//   -START:   Start condition: pulling SDA low while SCL is high
//   -SEND_SENSOR_ADDRESS1: Transmitting 7-bit sensor address + 1 R/W bit
//   -ACK_SENSOR_ADDRESS1:  Waiting for acknowledgment from the sensor
//   -SEND_REGISTER_ADDRESS: Sending the register address ( temperature register)
//   -ACK_REGISTER_ADDRESS:  Waiting for acknowledgment after sending register address
//   -REP_START:  Sending repeated start and switching to read mode
//   -SEND_SENSOR_ADDRESS2:      
//   -ACK_SENSOR_ADDRESS2:             
//   -READ_MSBYTE:  Reading the most significant byte (MSB) of temperature   
//   -ACK_MSBYTE:                    
//   -READ_LSBYTE:  Reading the least significant byte (LSB) of temperature
//   -STOP:    Stop condition: marking the end of communication
//-----------------------------------------------------------------------------
// Notes        : 
//   - The module is designed to support 7-bit addressing mode.
//   - Proper synchronization is maintained for SCL and SDA signals.
//   - Timing constraints are met as per the I2C specification.
//-----------------------------------------------------------------------------


/*the ack is not working maybe the hardware pullup or design*/
module i2c_controller_temp_sensor #(
    parameter SENSOR_ADDRESS = 7'b111_0000, // Default sensor address (7-bit)
    parameter CU_WIDTH = 16,               // Width of the control unit data
    parameter TARGET_READ_ADDRESS = 8'h00,// Address of the temperature register
    parameter SCL_DIVIDER = 50 // Adjust based on the desired SCL frequency
) (
    input  wire clk,                      // System clock signal for synchronization
    input  wire rst_n,                    // Active-low reset signal
    inout  wire  scl,                      // Serial clock line (I2C protocol)
    inout  wire sda,                      // Serial data line (I2C protocol, bidirectional)
    output wire [CU_WIDTH-1:0] sensor_out,  // Output data to the control unit
    output data_valid
);

    // FSM css for I2C operation
    typedef enum logic [4:0] {
        IDLE,                   // Idle cs: waiting for a transaction to start
        START,                  // Start condition: pulling SDA low while SCL is high
        WAIT_START,
        SEND_SENSOR_ADDRESS1,    // Transmitting 7-bit sensor address + 1 R/W bit
        WAIT_ADDR_LAST_BIT,
        WAIT_SCL_LOW,
        WAIT_SCL,
        ACK_SENSOR_ADDRESS1,           // Waiting for acknowledgment from the sensor
        SEND_REGISTER_ADDRESS,  // Sending the register address (e.g., temperature register)
        WAIT_SCL2,
        ACK_REGISTER_ADDRESS,   // Waiting for acknowledgment after sending register address
        PRE_REP_START,
        REP_START,         // Sending repeated start and switching to read mode
        SEND_SENSOR_ADDRESS2,      
        ACK_SENSOR_ADDRESS2,             
        READ_MSBYTE,         // Reading the most significant byte (MSB) of temperature   
        ACK_MSBYTE,                    
        READ_LSBYTE,        // Reading the least significant byte (LSB) of temperature
        NACK_LSBYTE,
        STOP            // Stop condition: marking the end of communication
    } fsm_css_t;

    // cs and next-cs registers for FSM
    fsm_css_t cs, ns;

    // Internal registers and signals
    reg [15:0] temp_data;       // Temporary register to store the temperature data

    reg [3:0] byte_count;      // Counter for bit transmission and reception
    wire en;               
    
    wire sda_out_en;             // Control signal to enable SDA as output
    logic sda_out,sda_out_r,sda_out_r_en;                // Output value for SDA line
    logic sda_r;
    
    logic scl_out,scl_out_r; // Register to hold SCL state
    wire scl_r;
    


    // Tri-cs logic for SDA line: driven by the module when sda_out_en is high
    assign sda = (sda_out_en) ? sda_r : 1'bz;
    assign sda_r = (sda_out_r === 0) ? 1'b0 : 1'bz;
    //when the module drives the sda line
    assign sda_out_en = (cs == READ_LSBYTE || cs == READ_MSBYTE || cs == ACK_SENSOR_ADDRESS1 ||
     cs == ACK_SENSOR_ADDRESS2 || cs == ACK_REGISTER_ADDRESS || cs == PRE_REP_START || cs == READ_MSBYTE ) ? 1'b0 : 1'b1;
    
    // Tri-cs logic for SDA line: driven by the module when sda_out_en is high
    assign scl = scl_r;
    assign scl_r = (scl_out) ? 1'bz : 1'b0;
    
    
    //assign the output of the sensor
    assign  sensor_out = temp_data; // Update output to the control unit
    //assign the data valid signal
    assign data_valid = (cs == READ_MSBYTE || cs == READ_LSBYTE || cs == ACK_MSBYTE) ? 1'b0 : 1'b1;

    assign en = (cs == IDLE || cs == START || cs == WAIT_START || cs == STOP || cs == REP_START  || cs == WAIT_SCL) ? 1'b0 : 1'b1;


    // FSM Sequential Logic: Update the cs on each clock edge or reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            cs <= IDLE; // Reset to IDLE cs
        else 
            cs <= ns; // Transition to the next cs
    end

    clk_divider #( .DIV(SCL_DIVIDER) ) clk_divider_inst // Divide clock frequency by DiV if DIV = 50
    (
        .clk_in  ( clk     ), // 150 MHz
        .rst_n   ( rst_n   ),
        .clk_out ( scl_out )  // 3 MHz
    );

    // Instantiate the counter
    counter #(
        .MAX_COUNT(8)
    ) byte_counter (
        .clk    (scl_out),
        .rst_n  (rst_n),
        .en     (en),
        .count  (byte_count)
    );

    // FSM Combinational Logic: Determine next cs and control signals
    always_comb begin : cs_logic
        // Default assignments for all signals
        ns = cs;
        sda_out = 1'b1;        // SDA high (idle cs)
        sda_out_r_en = 0;
        case (cs)
            IDLE: begin
                if(!scl_out_r)begin
                ns = START;
                end
            end
            START: begin
                // Generate start condition: SDA goes low while SCL is high 
                if(scl_out_r) begin
                    sda_out = 1'b0;    // SDA low for start
                    sda_out_r_en = 1;
                    ns = SEND_SENSOR_ADDRESS1;
                end else 
                    ns = START;
            end
            SEND_SENSOR_ADDRESS1: begin
                // Transmit 7-bit sensor address followed by 1-bit R/W
                if (!scl_out) begin
                    sda_out_r_en = 1;
                    if(byte_count < 7)begin
                        sda_out = SENSOR_ADDRESS[6 - byte_count]; // Send sensor address bit-by-bit
                    end else begin
                        sda_out = 1'b0;
                    end
                    if(byte_count == 8)begin 
                        ns = ACK_SENSOR_ADDRESS1;
                    end
                    end else begin
                    ns = SEND_SENSOR_ADDRESS1;
                end
            end
            ACK_SENSOR_ADDRESS1: begin 
                // Wait for acknowledgment from the slave (SDA pulled low)
                    if(byte_count == 0)begin
                        if (sda == 1'b0)begin 
                            ns = SEND_REGISTER_ADDRESS; // Proceed if acknowledgment received
                        end else begin
                            ns = WAIT_SCL2;
                            sda_out = sda;
                            sda_out_r_en = 1'b1;    
                        end
                    end
            end
            SEND_REGISTER_ADDRESS: begin
                // Transmit 7-bit target address followed by 1-bit R/W
                if (!scl_out) begin
                    sda_out_r_en = 1;
                    if(byte_count < 8)begin
                        sda_out = TARGET_READ_ADDRESS[7 - byte_count]; // Send sensor address bit-by-bit
                    end 
                    if(byte_count == 8)begin 
                        ns = ACK_REGISTER_ADDRESS;
                    end
                    end else begin
                    ns = SEND_REGISTER_ADDRESS;
                end
            end
            ACK_REGISTER_ADDRESS: begin
               // Wait for acknowledgment from the slave (SDA pulled low)
                    if(byte_count == 0)begin
                        if (sda == 1'b0)begin 
                            ns = PRE_REP_START; // Proceed if acknowledgment received
                        end else begin
                            ns = WAIT_SCL2;
                            sda_out = sda;
                            sda_out_r_en = 1'b1;    
                        end
                    end
            end
            PRE_REP_START:begin
                // Send repeated start condition and switch to read mode
                // Generate start condition: SDA goes low while SCL is high 
                if(!scl_out) begin
                    sda_out = 1'b1;    // SDA low for start
                    sda_out_r_en = 1;
                    ns = REP_START;
                end else 
                    ns = PRE_REP_START;
            end
            REP_START: begin
                // Send repeated start condition and switch to read mode
                // Generate start condition: SDA goes low while SCL is high 
                if(scl_out_r) begin
                    sda_out = 1'b0;    // SDA low for start
                    sda_out_r_en = 1;
                    ns = SEND_SENSOR_ADDRESS2;
                end else 
                    ns = REP_START;
            end
            SEND_SENSOR_ADDRESS2: begin
               // Transmit 7-bit sensor address followed by 1-bit R/W
                if (!scl_out) begin
                    sda_out_r_en = 1;
                    if(byte_count < 7)begin
                        sda_out = SENSOR_ADDRESS[6 - byte_count]; // Send sensor address bit-by-bit
                    end else begin
                        sda_out = 1'b1;
                    end
                    if(byte_count == 8)begin 
                        ns = ACK_SENSOR_ADDRESS2;
                    end
                    end else begin
                    ns = SEND_SENSOR_ADDRESS2;
                end
            end
            ACK_SENSOR_ADDRESS2: begin
                   // Wait for acknowledgment from the slave (SDA pulled low)
                    if(byte_count == 0)begin
                        if (sda == 1'b0)begin 
                            ns = READ_MSBYTE; // Proceed if acknowledgment received
                        end else begin
                            ns = WAIT_SCL2;
                            sda_out = sda;
                            sda_out_r_en = 1'b1;    
                        end
                    end
            end
            READ_MSBYTE: begin
                sda_out = sda;
                sda_out_r_en = 1'b1;
                // Read most significant byte (MSB) from the temperature register
                if(byte_count == 8)begin
                    ns = ACK_MSBYTE;
                end else begin
                    ns = READ_MSBYTE;
                end
            end
            ACK_MSBYTE:begin
                if(!scl_out)begin
                    sda_out = 1'b0;
                    sda_out_r_en = 1'b1;
                    // acknowledgment send to slave (SDA pulled low)
                    if(byte_count == 0)begin
                    ns = READ_LSBYTE; // Proceed after acknowledgment sent
                    end else begin
                    ns = ACK_MSBYTE;
                    end
                end
            end
            READ_LSBYTE: begin
                sda_out = sda;
                sda_out_r_en = 1'b1;
                // Read most significant byte (MSB) from the temperature register
                if(byte_count == 8)begin
                    ns = NACK_LSBYTE;
                end else begin
                    ns = READ_LSBYTE;
                end
            end
            NACK_LSBYTE:begin
                if(!scl_out)begin
                    sda_out = 1'b1;
                    sda_out_r_en = 1'b1;
                    // acknowledgment send to slave (SDA pulled low)
                    if(byte_count == 0)begin
                    ns = WAIT_SCL2; // Proceed after acknowledgment sent
                    end else begin
                    ns = NACK_LSBYTE;
                    end
                end
            end
            WAIT_SCL2:begin
                if(!scl_out_r)begin
                    ns = STOP;
                    sda_out = 1'b0;
                    sda_out_r_en = 1'b1;
                end else begin
                    ns = WAIT_SCL2;
                end
            end
            STOP: begin
                // Generate stop condition: SDA goes high while SCL is high
                if(scl_out_r == 1'b1)begin
                    ns = IDLE; // Return to IDLE cs
                    sda_out = 1'b1;
                    sda_out_r_en = 1'b1;
                end
            end
            default: ns = IDLE; // Default cs
        endcase
    end

    
always_ff @(posedge scl_out or negedge rst_n) begin : read_value_logic
    if(!rst_n)begin
        temp_data <= 1'b0;
    end else if(cs == READ_MSBYTE && byte_count < 8)begin
            temp_data[15-byte_count] <= sda ; // Store MSB
        end else if(cs == READ_LSBYTE && byte_count < 8) begin
            temp_data[7-byte_count] <= sda ; // Store LSB
            end
    end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        scl_out_r <= 1'b0;
    end else begin
        scl_out_r <= scl_out;
    end
    end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        sda_out_r <= 1'b1;
    end else if (sda_out_r_en && (byte_count < 8 || cs == ACK_MSBYTE || cs == NACK_LSBYTE)) begin
        sda_out_r <= sda_out;
        end
    end  
// // Check that if SDA goes high while SCL is high, we must be in STOP state
// property sda_rising_when_scl_high;
//     @(posedge sda) (scl == 1'b1) |-> (cs == STOP);
// endproperty

// // Check that if SDA goes low while SCL is high, we must be in START or REP_START
// property sda_falling_when_scl_high;
//     @(negedge sda) (scl == 1'b1) |-> (cs == START || cs == REP_START);
// endproperty

// assert_sda_rise: assert property (sda_rising_when_scl_high)
//     else $error("Assertion failed: SDA rose while SCL was high and not in STOP.");

// assert_sda_fall: assert property (sda_falling_when_scl_high)
//     else $error("Assertion failed: SDA fell while SCL was high and not in START or REP_START.");
      
endmodule