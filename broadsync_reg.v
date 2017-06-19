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
    output reg  [31:0]                 cpu_if_read_data = 0,
    output reg                         cpu_if_access_complete = 0
);

always @(posedge clk) begin
    if (reset) begin
        frame_en <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd1) begin
        frame_en <= cpu_if_write_data[0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        toggle_time_fractional_ns <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd2) begin
        toggle_time_fractional_ns <= cpu_if_write_data[FRAC_NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        toggle_time_nanosecond <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd3) begin
        toggle_time_nanosecond <= cpu_if_write_data[NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        toggle_time_seconds <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd4) begin
        toggle_time_seconds[31:0] <= cpu_if_write_data;
    end else if (cpu_if_write && cpu_if_address == 30'd5) begin
        toggle_time_seconds[S_WIDTH-1:32] <= cpu_if_write_data[S_WIDTH-32-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        half_period_fractional_ns <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd6) begin
        half_period_fractional_ns <= cpu_if_write_data[FRAC_NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        half_period_nanosecond <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd7) begin
        half_period_nanosecond <= cpu_if_write_data[NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        drift_rate <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd6) begin
        drift_rate <= cpu_if_write_data[FRAC_NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        time_offset[NS_WIDTH-1:0] <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd7) begin
        time_offset[NS_WIDTH-1:0] <= cpu_if_write_data[NS_WIDTH-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        time_offset[NS_WIDTH+S_WIDTH-1:NS_WIDTH] <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd8) begin
        time_offset[NS_WIDTH+31:NS_WIDTH] <= cpu_if_write_data;
    end else if (cpu_if_write && cpu_if_address == 30'd9) begin
        time_offset[NS_WIDTH+S_WIDTH-1:NS_WIDTH+32] <= cpu_if_write_data[S_WIDTH-32-1:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        lock_value_in <= 0;
        clk_accuracy_in <= 0;
    end else if (cpu_if_write && cpu_if_address == 30'd10) begin
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
    case (cpu_if_address)
        30'd1 : begin
            cpu_if_read_data <= cpu_if_read ? {frame_done_r,30'd0,frame_en} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd2 : begin
            cpu_if_read_data <= cpu_if_read ? {toggle_time_fractional_ns} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd3 : begin
            cpu_if_read_data <= cpu_if_read ? {toggle_time_nanosecond} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd4 : begin
            cpu_if_read_data <= cpu_if_read ? {toggle_time_seconds[31:0]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd5 : begin
            cpu_if_read_data <= cpu_if_read ? {toggle_time_seconds[S_WIDTH-1:32]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd6 : begin
            cpu_if_read_data <= cpu_if_read ? {half_period_fractional_ns} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd7 : begin
            cpu_if_read_data <= cpu_if_read ? {time_offset[NS_WIDTH-1:0]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd8 : begin
            cpu_if_read_data <= cpu_if_read ? {time_offset[NS_WIDTH+31:NS_WIDTH]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd9 : begin
            cpu_if_read_data <= cpu_if_read ? {time_offset[NS_WIDTH+S_WIDTH-1:NS_WIDTH+32]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd10 : begin
            cpu_if_read_data <= cpu_if_read ? {23'd0,lock_value_in,clk_accuracy_in} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd11 : begin
            cpu_if_read_data <= cpu_if_read ? {time_value_out_r[NS_WIDTH-1:0]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd12 : begin
            cpu_if_read_data <= cpu_if_read ? {time_value_out_r[NS_WIDTH+31:NS_WIDTH]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd13 : begin
            cpu_if_read_data <= cpu_if_read ? {time_value_out_r[NS_WIDTH+S_WIDTH-1:NS_WIDTH+32]} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
        30'd14 : begin
            cpu_if_read_data <= cpu_if_read ? {22'd0,frame_error_r,lock_value_out_r,clk_accuracy_out_r} : cpu_if_read_data;
            cpu_if_access_complete <= cpu_if_write|cpu_if_read;
        end
    endcase
end

endmodule
