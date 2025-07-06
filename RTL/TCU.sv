module temperature_CU #(
    parameter DAC_WIDTH = 8,           // Width of the output DAC control data
    parameter NOISE_THRESHOLD = 1,     // Threshold for noise immunity 1 degree
    // i2c controller Parameters
    parameter CU_WIDTH = 16                 //width of the control unit input
) (
    input                         clk,                 // Clock signal
    input                         rst_n,               // Active-low reset signal                  // Enable signal for the TCU from the SYS to start operation

    //air conditioner interface
    output                        on_off,              // Output to turn the control unit on or off
    output reg                    data_valid,          // Signal to indicate if data is valid
    output reg [DAC_WIDTH-1:0]    Control_unit_out,    // output data for DAC gives value that is indication about the temp weather it needs significant change wether increase or decrease or not 
    output wire                   increase_decrease_temp, //if 1 the air conditioner should increase the temperature else it decreases the temperature  
    
    //i2c interface
    input                         sensor_data_valid,          //indicates the sensor data is valid.
    input  [CU_WIDTH-1:0]         sensor_out           //the sensor reading of the temperature.
);

// Register to store the previous sensor value for comparison
reg [CU_WIDTH-1:0]   prev_sensor_in;
wire signed [7:0]   temperature;
logic [7:0] temp_diff; //To compute absolute difference from 25°C

    parameter                         en = 1; 

//Instantiate the temperature calculator
    temperature_calculator temp_calc (
        .sensor_in(sensor_out[11:0]),
        .temperature(temperature)
    );



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Active-low reset: Initialize outputs and registers to default values
        data_valid       <= 1'b0;             // Data is initially not valid
        Control_unit_out <= 'b0;              // Initialize control output to zero
        prev_sensor_in   <= 'b0;              // Reset previous sensor input to zero
    end else if (en) begin
        // When enable signal is active, check noise immunity threshold
        data_valid <= 1'b1;                   // Data is valid when enabled
        
        if (temperature > 25)begin
            temp_diff = temperature - 25;
        end else begin
            temp_diff = 25 - temperature;
        end
        
        // Calculate the absolute difference between the current and previous sensor input
        if (sensor_data_valid && (temperature > prev_sensor_in + NOISE_THRESHOLD) || (temperature < prev_sensor_in - NOISE_THRESHOLD)) begin
            // Update output if the sensor input change exceeds the noise threshold
            Control_unit_out <= (temp_diff * ((1 << DAC_WIDTH) - 1)) >> 8;  //scale the difference between required and current temp for better power consumtion in the air conditioner
            prev_sensor_in   <= temperature;    // Update previous sensor value
        end
        // If the change is within the noise threshold, Control_unit_out remains unchanged
    end else begin
        // If enable signal is not active, reset data_valid and on_off
        data_valid       <= 1'b0;
    end
end

assign on_off = (en && (temperature != 25));
assign increase_decrease_temp = ((temperature < 25));

endmodule
