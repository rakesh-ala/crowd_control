`timescale 1ns/1ps

module top_tb;

    // Inputs
    reg CLOCK_50 = 0;
    reg ECHO1 = 0;
    reg ECHO2 = 0;

    // Outputs
    wire TRIG1;
    wire TRIG2;
    wire [7:0] seg;
    wire [3:0] an;
    wire buzzer;

    // Instantiate the top module
    top uut (
        .CLOCK_50(CLOCK_50),
        .ECHO1(ECHO1),
        .ECHO2(ECHO2),
        .TRIG1(TRIG1),
        .TRIG2(TRIG2),
        .seg(seg),
        .an(an),
        .buzzer(buzzer)
    );

    // Clock generation: 50 MHz
    always #10 CLOCK_50 = ~CLOCK_50;

    // Task to simulate a person entering (ECHO1 then ECHO2)
    task simulate_entry;
        begin
            // Echo1 detects person (start pulse)
            ECHO1 <= 1;
            #1000; // simulate echo high duration
            ECHO1 <= 0;

            #50000; // wait a bit

            // Echo2 detects person
            ECHO2 <= 1;
            #1000;
            ECHO2 <= 0;

            #50000;
        end
    endtask

    // Task to simulate a person exiting (ECHO2 then ECHO1)
    task simulate_exit;
        begin
            ECHO2 <= 1;
            #1000;
            ECHO2 <= 0;

            #50000;

            ECHO1 <= 1;
            #1000;
            ECHO1 <= 0;

            #50000;
        end
    endtask

    initial begin
        $display("Starting simulation...");

        // Wait for system to stabilize
        #100000;

        // Simulate 50 people entering to reach capacity = 0
        repeat (50) begin
            simulate_entry();
        end

        // Check if buzzer is ON
        #10000;
        $display("Buzzer should be ON now, value: %b", buzzer);

        // Wait a bit
        #100000;

        // Simulate 1 person exiting
        simulate_exit();

        // Wait and check buzzer
        #10000;
        $display("Buzzer should be OFF now, value: %b", buzzer);

        // Finish simulation
        $finish;
    end
endmodule
