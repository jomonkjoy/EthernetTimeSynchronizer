// CDC from low to high clock frequency for CPU_IF
module cpu_if_cdc #( parameter SYNC_STAGE = 3 ) (
    input  wire        h_clk,
    input  wire        h_reset,

    output reg         h_cpu_if_read = 0,
    output reg         h_cpu_if_write = 0,
    output wire [31:0] h_cpu_if_write_data,
    output wire [31:2] h_cpu_if_address,
    input  wire [31:0] h_cpu_if_read_data,
    input  wire        h_cpu_if_access_complete,

    input  wire        l_clk,
    input  wire        l_reset,

    input  wire        l_cpu_if_read,
    input  wire        l_cpu_if_write,
    input  wire [31:0] l_cpu_if_write_data,
    input  wire [31:2] l_cpu_if_address,
    output wire [31:0] l_cpu_if_read_data,
    output reg         l_cpu_if_access_complete = 0
);

reg l_cpu_if_read_r1 = 0;
reg l_cpu_if_read_r2 = 0;

always @(posedge l_clk) begin
    l_cpu_if_read_r1 <= l_cpu_if_read;
    l_cpu_if_read_r2 <= l_cpu_if_read_r1;
end

wire l_cpu_if_read_pulse = ~l_cpu_if_read_r2 && l_cpu_if_read_r1;

pulse_sync #( .SYNC_STAGE(SYNC_STAGE) ) 
pulse_sync_l_cpu_if_read (
    .clk   ( h_clk ) ,
    .in    ( l_cpu_if_read ) ,
    .out   ( h_cpu_if_read_sync ) 
);

reg h_cpu_if_read_r1 = 0;
reg h_cpu_if_read_r2 = 0;

always @(posedge h_clk) begin
    h_cpu_if_read_r1 <= h_cpu_if_read_sync;
    h_cpu_if_read_r2 <= h_cpu_if_read_r1;
end

wire h_cpu_if_read_pulse = ~h_cpu_if_read_r2 && h_cpu_if_read_r1;

always @(posedge h_clk) begin
    h_cpu_if_read <= h_cpu_if_read_pulse;
end

pulse_sync #( .SYNC_STAGE(SYNC_STAGE) ) 
pulse_sync_l_cpu_if_write (
    .clk   ( h_clk ) ,
    .in    ( l_cpu_if_write ) ,
    .out   ( h_cpu_if_write_sync )
);

reg h_cpu_if_write_r1 = 0;
reg h_cpu_if_write_r2 = 0;

always @(posedge h_clk) begin
    h_cpu_if_write_r1 <= h_cpu_if_write_sync;
    h_cpu_if_write_r2 <= h_cpu_if_write_r1;
end

wire h_cpu_if_write_pulse = ~h_cpu_if_write_r2 && h_cpu_if_write_r1;

always @(posedge h_clk) begin
    h_cpu_if_write <= h_cpu_if_write_pulse;
end

data_sync_mux #( .DATA_WIDTH (32) )
data_sync_mux_l_cpu_if_write_data (
    .clk ( h_clk ) ,
    .sel ( h_cpu_if_write_pulse ) ,
    .in  ( l_cpu_if_write_data ) ,
    .out ( h_cpu_if_write_data )
);

data_sync_mux #( .DATA_WIDTH (30) )
data_sync_mux_l_cpu_if_address (
    .clk ( h_clk ) ,
    .sel ( h_cpu_if_write_pulse | h_cpu_if_read_pulse ) ,
    .in  ( l_cpu_if_address ) ,
    .out ( h_cpu_if_address )
);

reg h_cpu_if_access_complete_r1 = 0;
reg h_cpu_if_access_complete_r2 = 0;

always @(posedge h_clk) begin
    h_cpu_if_access_complete_r1 <= h_cpu_if_access_complete;
    h_cpu_if_access_complete_r2 <= h_cpu_if_access_complete_r1;
end

wire h_cpu_if_access_complete_pulse = ~h_cpu_if_access_complete_r2 && h_cpu_if_access_complete_r1;
reg  h_cpu_if_access_complete_latch = 0;

always @(posedge h_clk) begin
    h_cpu_if_access_complete_latch <= h_cpu_if_access_complete_latch ^ h_cpu_if_access_complete_pulse;
end

wire [31:0] h_cpu_if_read_data_latch;

data_sync_mux #( .DATA_WIDTH (32) )
data_sync_mux_h_cpu_if_read_data (
    .clk ( h_clk ) ,
    .sel ( h_cpu_if_access_complete_pulse ) ,
    .in  ( h_cpu_if_read_data ) ,
    .out ( h_cpu_if_read_data_latch )
);

pulse_sync #( .SYNC_STAGE(SYNC_STAGE) ) 
pulse_sync_h_cpu_if_access_complete_latch (
    .clk   ( l_clk ) ,
    .in    ( h_cpu_if_access_complete_latch ) ,
    .out   ( l_cpu_if_access_complete_latch ) 
);

reg l_cpu_if_access_complete_r1 = 0;
reg l_cpu_if_access_complete_r2 = 0;

always @(posedge l_clk) begin
    l_cpu_if_access_complete_r1 <= l_cpu_if_access_complete_latch;
    l_cpu_if_access_complete_r2 <= l_cpu_if_access_complete_r1;
end

wire l_cpu_if_access_complete_pulse = l_cpu_if_access_complete_r2 ^ l_cpu_if_access_complete_r1;

always @(posedge l_clk) begin
    l_cpu_if_access_complete <= l_cpu_if_access_complete_pulse;
end

reg l_cpu_if_read_valid = 0;

always @(posedge l_clk) begin
    if (l_reset) begin
        l_cpu_if_read_valid <= 0;
    end else if (l_cpu_if_access_complete_pulse) begin
        l_cpu_if_read_valid <= 0;
    end else begin
        l_cpu_if_read_valid <= l_cpu_if_read_valid ^ l_cpu_if_read_pulse;
    end
end

data_sync_mux #( .DATA_WIDTH (32) )
data_sync_mux_h_cpu_if_read_data_latch (
    .clk ( l_clk ) ,
    .sel ( l_cpu_if_access_complete_pulse & l_cpu_if_read_valid ) ,
    .in  ( h_cpu_if_read_data_latch ) ,
    .out ( l_cpu_if_read_data )
);

endmodule

module data_sync_mux #( parameter DATA_WIDTH = 1 ) (
    input  wire clk,
    input  wire sel,
    input  wire [DATA_WIDTH-1:0] in,
    output wire [DATA_WIDTH-1:0] out
);

reg [DATA_WIDTH-1:0] data = {DATA_WIDTH{1'b0}};

always @(posedge clk) begin
    data <= sel ? in : data;
end

assign out = data;

endmodule

module pulse_sync #( parameter SYNC_STAGE = 3 ) (
    input  wire clk,
    input  wire in,
    output wire out
);

reg [SYNC_STAGE-1:0] data = {SYNC_STAGE{1'b0}};

always @(posedge clk) begin
    data <= {data[SYNC_STAGE-2:0],in};
end

assign out = data[SYNC_STAGE-1];

endmodule
