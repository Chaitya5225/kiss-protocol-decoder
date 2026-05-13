// ============================================================================
// Author      : Chaitanya
// Date        : April 25, 2026
// Description : KISS Protocol Decoder 
//               Fully synchronous FSM with 256-byte payload enforcement.
// ============================================================================

`timescale 1ns / 1ps

module kiss_decoder (
    input  wire       clk,
    input  wire       reset,        // Active-high synchronous reset
    input  wire [7:0] rx_data,      // 8-bit incoming byte stream
    input  wire       rx_valid,     // High when rx_data is valid

    output reg  [7:0] data_out,     // Decoded raw payload byte
    output reg        data_valid,   // High for 1 clock cycle when data_out is valid
    output reg        start_frame,  // High for 1 clock cycle to indicate frame start
    output reg        end_frame     // High for 1 clock cycle to indicate frame end
);

    // -------------------------------------------------------------------------
    // KISS Protocol Constants
    // -------------------------------------------------------------------------
    localparam [7:0] FEND  = 8'hC0; // Frame End / Start
    localparam [7:0] FESC  = 8'hDB; // Frame Escape
    localparam [7:0] TFEND = 8'hDC; // Transposed Frame End
    localparam [7:0] TFESC = 8'hDD; // Transposed Frame Escape

    // FSM States 
    localparam [1:0] IDLE    = 2'b00;
    localparam [1:0] PAYLOAD = 2'b01;
    localparam [1:0] ESCAPE  = 2'b10;

    // Instruct synthesis tool to use one-hot encoding to maximize Fmax
    (* fsm_encoding = "one_hot" *) reg [1:0] state_reg;
    reg [8:0] byte_count; // 9-bit counter to track up to 256 bytes of payload

    // -------------------------------------------------------------------------
    // Single-Block Synchronous FSM
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state_reg   <= IDLE;
            data_out    <= 8'h00;
            data_valid  <= 1'b0;
            start_frame <= 1'b0;
            end_frame   <= 1'b0;
            byte_count  <= 9'd0;
        end else begin
            // Default assignments: Clear pulse signals unconditionally every clock edge.
            // This guarantees they are exactly 1-clock-cycle wide and prevents latches.
            data_valid  <= 1'b0;
            start_frame <= 1'b0;
            end_frame   <= 1'b0;

            if (rx_valid) begin
                case (state_reg)
                    
                    // STATE: Waiting for the start of a frame (FEND)
                    IDLE: begin
                        if (rx_data == FEND) begin
                            start_frame <= 1'b1;
                            byte_count  <= 9'd0; // Reset payload counter
                            state_reg   <= PAYLOAD;
                        end
                    end

                    // STATE: Receiving standard payload data
                    PAYLOAD: begin
                        if (rx_data == FEND) begin
                            // End of current frame
                            end_frame <= 1'b1;
                            state_reg <= IDLE;
                        end else if (byte_count == 9'd256) begin
                            // Enforce maximum payload size. Terminate if oversized.
                            end_frame <= 1'b1;
                            state_reg <= IDLE;
                        end else if (rx_data == FESC) begin
                            // Escape character detected, enter escape state
                            state_reg <= ESCAPE;
                        end else begin
                            // Standard payload byte
                            data_out   <= rx_data;
                            data_valid <= 1'b1;
                            byte_count <= byte_count + 1'b1;
                        end
                    end

                    // STATE: Resolving an escaped byte sequence
                    ESCAPE: begin
                        if (rx_data == FEND) begin
                            // Protocol violation: got FEND during escape. Resetting to IDLE to avoid lockup.
                            end_frame <= 1'b1;
                            state_reg <= IDLE;
                        end else if (byte_count == 9'd256) begin
                            // Drop frame if payload exceeds 256 bytes
                            end_frame <= 1'b1;
                            state_reg <= IDLE;
                        end else if (rx_data == TFEND) begin
                            data_out   <= FEND;
                            data_valid <= 1'b1;
                            byte_count <= byte_count + 1'b1;
                            state_reg  <= PAYLOAD;
                        end else if (rx_data == TFESC) begin
                            data_out   <= FESC;
                            data_valid <= 1'b1;
                            byte_count <= byte_count + 1'b1;
                            state_reg  <= PAYLOAD;
                        end else begin
                            // Invalid escape sequence. Drop byte and return to payload.
                            state_reg <= PAYLOAD;
                        end
                    end

                    default: begin
                        state_reg <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule
