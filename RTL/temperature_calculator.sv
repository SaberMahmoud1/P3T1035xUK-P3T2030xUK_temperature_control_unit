module temperature_calculator (
    input  [11:0] sensor_in,  // 12-bit input from the sensor
    output reg signed [7:0] temperature // Signed 8-bit output for temperature
);

    // Precomputed scaling factor: RESOLUTION = 0.0625 * 2^16 = 4096
    localparam RESOLUTION = 16'd4096;  // Fixed-point scaled factor

    reg signed [19:0] temp_scaled; // Intermediate result with extra bits

    always @(*) begin
            // Positive temperature
            temperature = sensor_in; // Equivalent to dividing by 65536
    end

endmodule
