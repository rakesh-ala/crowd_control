module ultrasonic(
    input clk,
    input echo,
    output trigger,
    output reg [20:0] distance_raw,
    output reg new_measure,
    output timeout
);
    parameter CLK_MHZ = 50;
    parameter TRIGGER_PULSE_US = 12;
    parameter TIMEOUT_MS = 25;

    localparam COUNT_TRIGGER_PULSE = CLK_MHZ * TRIGGER_PULSE_US;
    localparam COUNT_TIMEOUT = CLK_MHZ * TIMEOUT_MS * 1000;
    localparam PING_PERIOD = CLK_MHZ * 60000;  // Ping every 60ms

    reg [2:0] state = 0;
    localparam IDLE = 0, TRIG = 1, WAIT_ECHO_UP = 2, MEASURE = 3, DONE = 4;

    reg [31:0] counter = 0;
    reg [31:0] ping_timer = 0;

    assign trigger = (state == TRIG);
    assign timeout = (state == DONE) && (counter >= COUNT_TIMEOUT);

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                new_measure <= 0;
                counter <= 0;
                if (ping_timer >= PING_PERIOD) begin
                    ping_timer <= 0;
                    state <= TRIG;
                end else begin
                    ping_timer <= ping_timer + 1;
                end
            end

            TRIG: begin
                if (counter < COUNT_TRIGGER_PULSE) begin
                    counter <= counter + 1;
                end else begin
                    counter <= 0;
                    state <= WAIT_ECHO_UP;
                end
            end

            WAIT_ECHO_UP: begin
                if (echo) begin
                    counter <= 0;
                    state <= MEASURE;
                end else if (counter >= COUNT_TIMEOUT) begin
                    state <= DONE;
                end else begin
                    counter <= counter + 1;
                end
            end

            MEASURE: begin
                if (~echo || counter >= COUNT_TIMEOUT) begin
                    distance_raw <= counter;
                    new_measure <= 1;
                    state <= DONE;
                end else begin
                    counter <= counter + 1;
                end
            end

            DONE: begin
                state <= IDLE;
            end
        endcase
    end
endmodule
module seven_segment(
    input clk,
    input [6:0] value,
    output reg [3:0] an,
    output reg [7:0] seg
);
    reg [15:0] refresh_counter = 0;
    wire refresh_clk = refresh_counter[15];
    reg digit_select = 0;

    wire [3:0] digit0 = value % 10;
    wire [3:0] digit1 = value / 10;

    always @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end

    always @(posedge refresh_clk) begin
        digit_select <= ~digit_select;
    end

    always @(*) begin
           
        case (digit_select ? digit1 : digit0)
            4'd0: seg = 8'b11000000;
            4'd1: seg = 8'b11111001;
            4'd2: seg = 8'b10100100;
            4'd3: seg = 8'b10110000;
            4'd4: seg = 8'b10011001;
            4'd5: seg = 8'b10010010;
            4'd6: seg = 8'b10000010;
            4'd7: seg = 8'b11111000;
            4'd8: seg = 8'b10000000;
            4'd9: seg = 8'b10010000;
            default: seg = 8'b11111111;
        endcase

        // Only right 2 digits active: an[1:0]
        case (digit_select)
            1'b0: an = 4'b1110; // units (right)
            1'b1: an = 4'b1101; // tens (left)
            
        endcase
    end
endmodule

module top(
    input CLOCK_50,
    input ECHO1, // Sensor 1: Outside
    input ECHO2, // Sensor 2: Inside
    output TRIG1,
    output TRIG2,
    output [7:0] seg,
    output [3:0] an,
    output reg buzzer
 
);
    wire [20:0] dist1, dist2;
    wire new1, new2;
    wire timeout1, timeout2;

    localparam THRESHOLD = 2900 * 50; // 50 cm (raw value threshold)

    reg [6:0] capacity = 50;

    // FSM states
    reg [1:0] state = 0;
    localparam IDLE = 0, WAIT_FOR_2 = 1, WAIT_FOR_1 = 2;

    ultrasonic U1(
        .clk(CLOCK_50),
        .echo(ECHO1),
        .trigger(TRIG1),
        .distance_raw(dist1),
        .new_measure(new1),
        .timeout(timeout1)
    );

    ultrasonic U2(
        .clk(CLOCK_50),
        .echo(ECHO2),
        .trigger(TRIG2),
        .distance_raw(dist2),
        .new_measure(new2),
        .timeout(timeout2)
    );

    always @(posedge CLOCK_50) begin
        case (state)
            IDLE: begin
                if (new1 && dist1 < THRESHOLD) begin
                    state <= WAIT_FOR_2; // Expect inside next (entry)
                end else if (new2 && dist2 < THRESHOLD) begin
                    state <= WAIT_FOR_1; // Expect outside next (exit)
                end
            end

            WAIT_FOR_2: begin
                if (new2 && dist2 < THRESHOLD) begin
                    if (capacity > 0) capacity <= capacity - 1; // Entry → decrease
                    state <= IDLE;
                end else if (new1 && dist1 >= THRESHOLD) begin
                    state <= IDLE; // Reset on timeout or miss
                end
            end

            WAIT_FOR_1: begin
                if (new1 && dist1 < THRESHOLD) begin
                    if (capacity < 50) capacity <= capacity + 1; // Exit → increase
                    state <= IDLE;
                end else if (new2 && dist2 >= THRESHOLD) begin
                    state <= IDLE;
                end
            end
        endcase
        
        buzzer <= (capacity == 0);
    end
  
    seven_segment display(
        .clk(CLOCK_50),
        .value(capacity),
        .an(an),
        .seg(seg)
    );
endmodule