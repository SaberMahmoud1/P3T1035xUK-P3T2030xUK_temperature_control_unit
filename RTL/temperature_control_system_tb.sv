`timescale 1ns/1ps

module tb_i2c_controller_temp_sensor(inout sda);

    // Parameters for the temperature_CU module
    localparam DAC_WIDTH = 8;
    localparam NOISE_THRESHOLD = 1;
    localparam SENSOR_ADDRESS = 7'b1111111;
    localparam CU_WIDTH = 16;
    localparam TARGET_READ_ADDRESS = 8'b11111111;
    localparam SCL_DIVIDER = 50;

    // Testbench Signals
    reg clk_n,clk_p;
    reg rst_n;
    wire scl;
    reg sda_in;
    wire [CU_WIDTH-1:0] sensor_out;
    wire data_valid;
    logic tb_sda_out_en;

    logic [7:0] sensor_address;
    logic [7:0] temp_sensor_address;
    logic [7:0] temp;
    logic en;

    logic [CU_WIDTH-1:0] temp_data;
    logic [DAC_WIDTH-1:0] Control_unit_out;
    wire                   increase_decrease_temp;
    logic sda_in_r;
    // Tri-cs logic for SDA line: driven by the module when tb_sda_out_en is high
    assign sda = (tb_sda_out_en) ? sda_in_r : 1'bz;
    assign sda_in_r = (sda_in === 0) ? 1'b0 : 1'bz;



    pullup(scl);
    pullup(sda);

    // Instantiation of the temperature_CU module
    TCU_wrapper #(
        .DAC_WIDTH(DAC_WIDTH),
        .NOISE_THRESHOLD(NOISE_THRESHOLD),
        .SENSOR_ADDRESS(SENSOR_ADDRESS),
        .CU_WIDTH(CU_WIDTH),
        .TARGET_READ_ADDR(TARGET_READ_ADDRESS),
        .SCL_DIVIDER(SCL_DIVIDER)
    ) temp_control_unit (
        .clk(clk_n),
        // .clk_p(clk_p),
        .rst_n(rst_n),
        .on_off(on_off),
        .data_valid(data_valid),
        .Control_unit_out(Control_unit_out),
        .sda(sda),
        .scl(scl),
        .increase_decrease_temp(increase_decrease_temp)
    );

    assign sensor_out = temp_control_unit.sensor_out;
     // Clock generation for 150 MHz simulation (differential input)
    initial begin
        clk_p = 0;
        clk_n = 0;
        forever begin
            #3.3333 clk_p = ~clk_p;  // Toggle clk_p (half of the period)
            #3.3333 clk_n = ~clk_n;  // Toggle clk_n (half of the period)
        end
    end

    integer i=  0 ;

    assign tb_sda_out_en = !temp_control_unit.i2c_inst.sda_out_en;
    // Reset and Test Sequence
    initial begin
        // Initialize inputs
        rst_n = 0;

        // Hold reset for 100 ns
        #100;
        rst_n = 1;
        
    //sensor address
        repeat(1)begin
        en=1;
        
        @(negedge sda);
        if(scl == 1)
        $display("start condition detected");
        else 
        $display("start condition not detected");

        repeat(8)begin
        @(posedge scl);
        sensor_address[7-i] = sda;
        i=i+1;
        end
        if(sensor_address[7:1] == SENSOR_ADDRESS && sensor_address[0] == 1'b1)begin
        $display("first phase success address of the device + write bit %b",sensor_address);
        //send ack
        @(negedge scl);
        sda_in = 1'b0;
        @(negedge scl);
        end else begin
        $display("first phase failed recived data is %b",sensor_address);
        //send ack
        // @(negedge scl);
        // sda_in = 1'b1;
        // @(negedge scl);
        continue;
        end
    i=0;
    //temperature sensor address
        repeat(8)begin
        @(posedge scl);
        temp_sensor_address[7-i] = sda;
        i=i+1;
        end
        if(temp_sensor_address == TARGET_READ_ADDRESS )
        $display("second phase success the recived address is as expected");
        else
        $display("second phase failed recived data is %b",temp_sensor_address);
        
        //send ack
        @(negedge scl);
        sda_in = 1'b0;
        @(negedge scl);

        //repeated start
        @(negedge sda);
        if(scl == 1'b1)
        $display("3th phase success repeated start detected");
        else
        $display("3th phase failed repeated start not detected");

        //device address
        i=0;
        repeat(8)begin
        @(posedge scl);
        temp[7-i] = sda;
        i=i+1;
        end
        if(temp[7:1] == SENSOR_ADDRESS && temp[0] == 1'b1)
        $display("4th phase success SENSOR_ADDRESS and read bit recived");
        else
        $display("4th phase failed SENSOR_ADDRESS recived data is %b",temp);
        
        //send ack
        @(negedge scl);

        sda_in = 1'b0;

    i=0;

        //send MSBYTE
        repeat(8)begin
        @(negedge scl);
        @(posedge clk_n);
        
        sda_in = $random;

        temp_data[15-i]=sda_in;
        i=i+1;
        end
        $display("5th phase check MSBYTE sent");
        
        @(negedge scl);
        //recive ack
        @(posedge scl)
        if(sda == 1'b0)
        $display("6th phase success ack recived");

       //SEND LSBYTE
        repeat(8)begin
        @(negedge scl);
        @(posedge clk_n);
        sda_in = $random;
        temp_data[15-i]=sda_in;
        i=i+1;
        end
        $display("7th phase check LSBYTE sent");
        $display("sent data from the sensor is %b",temp_data);

        @(negedge scl);
        if(temp_data == sensor_out)
        $display("8th phase success sent data == sensor_out = %b",sensor_out);
        else
        $display("8th phase failed sent data = %b",sensor_out);
        //wait nack
        @(posedge scl);
        if(sda === 1)
        $display("NACK detected");

        @(posedge sda);
        if(scl === 1'b1)
        $display("stop condition detected");
        end

        #10000;
        // End simulation
        $stop;
    end
    

endmodule
