// ============================================================================
// Author      : Chaitanya
// Date        : April 25, 2026
// Description : KISS Protocol Decoder  
//               Fully synchronous FSM with 256-byte payload enforcement.
// ============================================================================

`timescale 1ns / 1ps

module tb_kiss_decoder();

    // Wires and Regs
    reg clk;
    reg reset;
    reg [7:0] rx_data;
    reg rx_valid;

    wire [7:0] data_out;
    wire data_valid;
    wire start_frame;
    wire end_frame;
    
    integer i;

    // Device Under Test (DUT) Instantiation
    kiss_decoder dut (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .data_out(data_out),
        .data_valid(data_valid),
        .start_frame(start_frame),
        .end_frame(end_frame)
    );

    // Clock Generation (100MHz = 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Data Injection Task
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            rx_data  <= data;
            rx_valid <= 1'b1;
            
            @(posedge clk);
            rx_valid <= 1'b0;
            
            // Add a 1-clock-cycle gap to simulate realistic serial behavior
            @(posedge clk); 
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize Inputs
        reset    = 1'b1;
        rx_data  = 8'h00;
        rx_valid = 1'b0;

        // Hold reset for 100ns
        #100;
        @(posedge clk);
        reset = 1'b0;
        #20;

        // TEST CASE 1: Standard Frame
        $display("Sending Test 1: Standard Frame...");
        send_byte(8'hC0); // Start FEND
        send_byte(8'hAA); // Data
        send_byte(8'hBB); // Data
        send_byte(8'hC0); // End FEND
        #50;

        // TEST CASE 2: Frame with Escaped Characters
        $display("Sending Test 2: Escaped Characters...");
        send_byte(8'hC0); // Start FEND
        send_byte(8'hDB); // FESC
        send_byte(8'hDD); // TFESC (Decodes to DB)
        send_byte(8'hDB); // FESC
        send_byte(8'hDC); // TFEND (Decodes to C0)
        send_byte(8'h11); // Standard Data
        send_byte(8'hC0); // End FEND
        #50;

        // TEST CASE 3: The "IDLE Leak" Check
        // Sending data while in IDLE state - shouldn't output anything
        $display("Sending Test 3: IDLE Leak Check...");
        send_byte(8'h22); // Should be ignored
        send_byte(8'hDB); // Should be ignored
        send_byte(8'hC0); // Starts a new frame instead!
        send_byte(8'h55); // Standard Data
        send_byte(8'hC0); // End FEND
        #50;

        // TEST CASE 4: Full 256-Byte Payload Boundary Check
        $display("Sending Test 4: Full 256-Byte Payload...");
        send_byte(8'hC0); // Start FEND
        for (i = 0; i < 256; i = i + 1) begin
            send_byte(8'h77); // Standard Data 
        end
        send_byte(8'hC0); // End FEND
        #50;

        // Automated Verification Check
        $display("-----------------------------------------");
        if (dut.byte_count == 9'd0 && dut.state_reg == 2'b00) begin
            $display("SUCCESS: FSM successfully returned to IDLE state.");
        end else begin
            $display("ERROR: FSM is stuck in state %b", dut.state_reg);
        end
        $display("-----------------------------------------");
        
        $display("Simulation Complete.");
        $finish;
    end

endmodule
