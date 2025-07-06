module TCU_wrapper #(
    parameter DAC_WIDTH        = 8,
    parameter CU_WIDTH         = 16,
    parameter NOISE_THRESHOLD  = 1,
    parameter SENSOR_ADDRESS   = 7'b0000000,
    parameter TARGET_READ_ADDR = 8'b00000000,
    parameter SCL_DIVIDER      = 50
)(
    input                   clk,
    // input                   clk_n,
    input                   rst_n, 
    inout                   sda,
    inout                   scl,
    output                  on_off,
    output                  data_valid,
    output [DAC_WIDTH-1:0]  Control_unit_out,
    output                  increase_decrease_temp
);

    wire [CU_WIDTH-1:0] sensor_out;
    wire sensor_data_valid;
    logic clk_sys;

    assign clk_sys = clk;

    // // Clock Wizard Instance
    // clk_wiz_0 clk_wiz_inst (
    //     .clk_out1(clk_sys),
    //     .clk_in1_p(clk_p),
    //     .clk_in1_n(clk_n)
    // );

    // I2C Controller Instance
    i2c_controller_temp_sensor #(
        .SENSOR_ADDRESS(SENSOR_ADDRESS),
        .CU_WIDTH(CU_WIDTH),
        .TARGET_READ_ADDRESS(TARGET_READ_ADDR),
        .SCL_DIVIDER(SCL_DIVIDER)
    ) i2c_inst (
        .clk(clk_sys),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .sensor_out(sensor_out),
        .data_valid(sensor_data_valid)
    );

    // Temperature Control Unit Instance
    temperature_CU #(
        .DAC_WIDTH(DAC_WIDTH),
        .NOISE_THRESHOLD(NOISE_THRESHOLD),
        .CU_WIDTH(CU_WIDTH)
    ) tcu_inst (
        .clk(clk_sys),
        .rst_n(rst_n),
        .sensor_data_valid(sensor_data_valid),
        .sensor_out(sensor_out),
        .on_off(on_off),
        .data_valid(data_valid),
        .Control_unit_out(Control_unit_out),
        .increase_decrease_temp(increase_decrease_temp)
    );

    // // ILA for debugging
    // ila_0 ila_i (
    //     .clk(clk_sys),
    //     .probe0(on_off),
    //     .probe1(data_valid),
    //     .probe2(Control_unit_out),
    //     .probe3(increase_decrease_temp),
    //     .probe4(rst_n),
    //     .probe5(sensor_data_valid),
    //     .probe6(sensor_out), // Optional: Truncate if needed
    //     .probe7(tcu_inst.temperature),
    //     .probe8(i2c_inst.scl_out_r),
    //     .probe9(i2c_inst.sda_out_r),
    //     .probe10(i2c_inst.cs),
    //     .probe11(i2c_inst.ns)
    // );

endmodule
