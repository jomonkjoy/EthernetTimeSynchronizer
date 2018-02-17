// CSR for broadsync interface master/slave
module broadsync_reg #(
    parameter FRAC_NS_WIDTH = 30,
    parameter NS_WIDTH = 30,
    parameter S_WIDTH = 48
) (
    input  wire                        clk,
    input  wire                        reset,

    output reg                         frame_en,
    input  wire                        frame_done,
    output reg                         lock_value_in,
    output reg  [7:0]                  clk_accuracy_in,
    input  wire                        lock_value_out,
    input  wire [S_WIDTH+NS_WIDTH+1:0] time_value_out,
    input  wire [7:0]                  clk_accuracy_out,
    input  wire                        frame_error,

    output reg  [FRAC_NS_WIDTH-1:0]    toggle_time_fractional_ns,
    output reg  [NS_WIDTH-1:0]         toggle_time_nanosecond,
    output reg  [S_WIDTH-1:0]          toggle_time_seconds,
    output reg  [FRAC_NS_WIDTH-1:0]    half_period_fractional_ns,
    output reg  [NS_WIDTH-1:0]         half_period_nanosecond,
    output reg  [FRAC_NS_WIDTH-0:0]    drift_rate,
    output reg  [S_WIDTH+NS_WIDTH-0:0] time_offset,

    input  wire                        cpu_if_read,
    input  wire                        cpu_if_write,
    input  wire [31:0]                 cpu_if_write_data,
    input  wire [31:2]                 cpu_if_address,
    output reg  [31:0]                 cpu_if_read_data,
    output reg                         cpu_if_access_complete
);

always @(posedge clk) begin
    if (reset) begin
        frame_en <= 1'b0;
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h0) begin
        frame_en <= cpu_if_write_data[0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        toggle_time_fractional_ns <= {FRAC_NS_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h1) begin
        toggle_time_fractional_ns <= cpu_if_write_data[FRAC_NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        toggle_time_nanosecond <= {NS_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h2) begin
        toggle_time_nanosecond <= cpu_if_write_data[NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        toggle_time_seconds <= {S_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h3) begin
        toggle_time_seconds[31:0] <= cpu_if_write_data;
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h4) begin
        toggle_time_seconds[S_WIDTH-1:32] <= cpu_if_write_data[S_WIDTH-32-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        half_period_fractional_ns <= {FRAC_NS_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h5) begin
        half_period_fractional_ns <= cpu_if_write_data[FRAC_NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        half_period_nanosecond <= {NS_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h6) begin
        half_period_nanosecond <= cpu_if_write_data[NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        drift_rate <= {FRAC_NS_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h7) begin
        drift_rate <= cpu_if_write_data[FRAC_NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        time_offset[NS_WIDTH-1:0] <= {NS_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h8) begin
        time_offset[NS_WIDTH-1:0] <= cpu_if_write_data[NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        time_offset[NS_WIDTH+S_WIDTH-1:NS_WIDTH] <= {S_WIDTH{1'b0}};
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'h9) begin
        time_offset[NS_WIDTH+31:NS_WIDTH] <= cpu_if_write_data;
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'hA) begin
        time_offset[NS_WIDTH+S_WIDTH-1:NS_WIDTH+32] <= cpu_if_write_data[S_WIDTH-32-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        lock_value_in <= 1'b0;
        clk_accuracy_in <= 8'd0;
    end else if (cpu_if_write && cpu_if_address[5:2] == 4'hB) begin
        lock_value_in <= cpu_if_write_data[8];
        clk_accuracy_in <= cpu_if_write_data[7:0];
    end
end

reg frame_done_r = 0;
always @(posedge clk) begin
    frame_done_r <= frame_done;
end

reg lock_value_out_r = 0;
always @(posedge clk) begin
    lock_value_out_r <= lock_value_out;
end

reg [S_WIDTH+NS_WIDTH+1:0] time_value_out_r = 0;
always @(posedge clk) begin
    time_value_out_r <= time_value_out;
end

reg [7:0] clk_accuracy_out_r = 0;
always @(posedge clk) begin
    clk_accuracy_out_r <= clk_accuracy_out;
end

reg frame_error_r = 0;
always @(posedge clk) begin
    frame_error_r <= frame_error;
end

always @(posedge clk) begin
    cpu_if_access_complete <= cpu_if_write|cpu_if_read;
end

always @(posedge clk) begin
    case (cpu_if_address[5:2])
        4'h0    : cpu_if_read_data <= {frame_done_r,30'd0,frame_en};
        4'h1    : cpu_if_read_data <= {toggle_time_fractional_ns};
        4'h2    : cpu_if_read_data <= {toggle_time_nanosecond};
        4'h3    : cpu_if_read_data <= {toggle_time_seconds[31:0]};
        4'h4    : cpu_if_read_data <= {toggle_time_seconds[S_WIDTH-1:32]};
        4'h5    : cpu_if_read_data <= {half_period_fractional_ns};
        4'h6    : cpu_if_read_data <= {time_offset[NS_WIDTH-1:0]};
        4'h7    : cpu_if_read_data <= {time_offset[NS_WIDTH+31:NS_WIDTH]};
        4'h8    : cpu_if_read_data <= {time_offset[NS_WIDTH+S_WIDTH-1:NS_WIDTH+32]};
        4'h9    : cpu_if_read_data <= {23'd0,lock_value_in,clk_accuracy_in};
        4'hA    : cpu_if_read_data <= {time_value_out_r[NS_WIDTH-1:0]};
        4'hB    : cpu_if_read_data <= {time_value_out_r[NS_WIDTH+31:NS_WIDTH]};
        4'hC    : cpu_if_read_data <= {time_value_out_r[NS_WIDTH+S_WIDTH-1:NS_WIDTH+32]};
        4'hD    : cpu_if_read_data <= {22'd0,frame_error_r,lock_value_out_r,clk_accuracy_out_r};
        default : cpu_if_read_data <= {32{1'b0}};
    endcase
end

endmodule
