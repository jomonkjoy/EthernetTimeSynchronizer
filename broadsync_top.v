// Ethernet Time Synchronization
module broadsync_top #(
    parameter BITCLK_TIMEOUT = 100*1024,
    parameter M_TIMEOUT_WIDTH = 8,
    parameter S_TIMEOUT_WIDTH = 64,
    parameter FRAC_NS_WIDTH = 30,
    parameter NS_WIDTH = 30,
    parameter S_WIDTH = 48
) (
    input  wire                        ptp_clk,
    input  wire                        ptp_reset,

    input  wire                        bitclock_in,
    input  wire                        heartbeat_in,
    input  wire                        timecode_in,

    output wire                        bitclock_out,
    output wire                        heartbeat_out,
    output wire                        timecode_out,

    input  wire                        frame_en,
    output wire                        frame_done,
    input  wire                        lock_value_in,
    input  wire [7:0]                  clk_accuracy_in,
    output wire                        lock_value_out,
    output wire [S_WIDTH+NS_WIDTH+1:0] time_value_out,
    output wire [7:0]                  clk_accuracy_out,
    output wire                        frame_error,


    input  wire [FRAC_NS_WIDTH-1:0]    toggle_time_fractional_ns,
    input  wire [NS_WIDTH-1:0]         toggle_time_nanosecond,
    input  wire [S_WIDTH-1:0]          toggle_time_seconds,
    input  wire [FRAC_NS_WIDTH-1:0]    half_period_fractional_ns,
    input  wire [NS_WIDTH-1:0]         half_period_nanosecond,
    input  wire [FRAC_NS_WIDTH-0:0]    drift_rate,
    input  wire [S_WIDTH+NS_WIDTH-0:0] time_offset
);

wire gtm_clk;
wire gtm_clk_en;

wire [S_WIDTH+NS_WIDTH+1:0] sync_time;

broadsync_master #(
    .TIMEOUT_WIDTH(M_TIMEOUT_WIDTH),
    .FRAC_NS_WIDTH(FRAC_NS_WIDTH),
    .NS_WIDTH(NS_WIDTH),
    .S_WIDTH(S_WIDTH)
) broadsync_master (
    .ptp_clk(ptp_clk),
    .ptp_reset(ptp_reset),

    .gtm_clk(gtm_clk),
    .gtm_clk_en(gtm_clk_en),
    .frame_en(frame_en),
    .frame_done(frame_done),
    .lock_value(lock_value_in),
    .time_value(sync_time),
    .clk_accuracy(clk_accuracy_in),

    .bitclock_out(bitclock_out),
    .heartbeat_out(heartbeat_out),
    .timecode_out(timecode_out)
);

broadsync_slave #(
    .BITCLK_TIMEOUT(BITCLK_TIMEOUT),
    .TIMEOUT_WIDTH(S_TIMEOUT_WIDTH),
    .FRAC_NS_WIDTH(FRAC_NS_WIDTH),
    .NS_WIDTH(NS_WIDTH),
    .S_WIDTH(S_WIDTH)
) broadsync_slave (
    .ptp_clk(ptp_clk),
    .ptp_reset(ptp_reset),

    .lock_value(lock_value_out),
    .time_value(time_value_out),
    .clk_accuracy(clk_accuracy_out),
    .frame_error(frame_error),

    .bitclock_in(bitclock_in),
    .heartbeat_in(heartbeat_in),
    .timecode_in(timecode_in)
);

broadsync_gtm #(
    .FRAC_NS_WIDTH(FRAC_NS_WIDTH),
    .NS_WIDTH(NS_WIDTH),
    .S_WIDTH(S_WIDTH)
) broadsync_gtm (
    .ptp_clk(ptp_clk),
    .ptp_reset(ptp_reset),

    .toggle_time_fractional_ns(toggle_time_fractional_ns),
    .toggle_time_nanosecond(toggle_time_nanosecond),
    .toggle_time_seconds(toggle_time_seconds),
    .half_period_fractional_ns(half_period_fractional_ns),
    .half_period_nanosecond(half_period_nanosecond),
    .drift_rate(drift_rate),
    .time_offset(time_offset),

    .gtm_clk(gtm_clk),
    .gtm_clk_en(gtm_clk_en),
    .sync_time(sync_time)
);

endmodule

module broadsync_gtm #( 
    parameter FRAC_NS_WIDTH = 30,
    parameter NS_WIDTH = 30,
    parameter S_WIDTH = 48
) (
    input  wire                        ptp_clk,
    input  wire                        ptp_reset,

    input  wire [FRAC_NS_WIDTH-1:0]    toggle_time_fractional_ns,
    input  wire [NS_WIDTH-1:0]         toggle_time_nanosecond,
    input  wire [S_WIDTH-1:0]          toggle_time_seconds,
    input  wire [FRAC_NS_WIDTH-1:0]    half_period_fractional_ns,
    input  wire [NS_WIDTH-1:0]         half_period_nanosecond,
    input  wire [FRAC_NS_WIDTH-0:0]    drift_rate,
    input  wire [S_WIDTH+NS_WIDTH-0:0] time_offset,

    output reg                         gtm_clk = 1'b0,
    output reg                         gtm_clk_en = 1'b0,
    output wire [S_WIDTH+NS_WIDTH+1:0] sync_time
);

localparam FRC_WIDTH = S_WIDTH+NS_WIDTH+FRAC_NS_WIDTH;
localparam HPC_WIDTH = NS_WIDTH+FRAC_NS_WIDTH;

//  PTP-free running time-of-day counter 
reg  [FRC_WIDTH-1:0] free_running_counter = {FRC_WIDTH{1'b0}};
reg  [FRC_WIDTH-0:0] free_running_counter_drift_adjusted = {FRC_WIDTH+1{1'b0}};
reg  [FRC_WIDTH+1:0] free_running_counter_offset_adjusted = {FRC_WIDTH+2{1'b0}};
reg  [FRC_WIDTH+1:0] cpu_init_toggle_time = {FRC_WIDTH+2{1'b0}};
reg  [FRC_WIDTH+1:0] cpu_prog_half_period = {FRC_WIDTH+2{1'b0}};
reg  [FRC_WIDTH+1:0] cpu_prog_half_period_r = {FRC_WIDTH+2{1'b0}};

assign sync_time = free_running_counter_offset_adjusted[FRC_WIDTH+1:FRAC_NS_WIDTH];

wire [FRC_WIDTH-1:0] toggle_time;
wire [HPC_WIDTH-1:0] half_period;

assign toggle_time = {toggle_time_seconds,toggle_time_nanosecond,toggle_time_fractional_ns};
assign half_period = {half_period_nanosecond,half_period_fractional_ns};

reg signed [FRAC_NS_WIDTH-0:0]    drift_adjustment;
reg signed [S_WIDTH+NS_WIDTH-0:0] offset_adjustment;

always @(posedge ptp_clk) begin
    cpu_init_toggle_time <= toggle_time;
    cpu_prog_half_period <= half_period;
end

always @(posedge ptp_clk) begin
    cpu_prog_half_period_r <= cpu_prog_half_period + cpu_init_toggle_time;
end

always @(posedge ptp_clk) begin
    drift_adjustment <= drift_rate;
    offset_adjustment <= time_offset;
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        free_running_counter <= {FRC_WIDTH{1'b0}};
    end else begin
        free_running_counter <= free_running_counter + 1;
    end
end

always @(posedge ptp_clk) begin
    free_running_counter_drift_adjusted <= free_running_counter + drift_adjustment;
    free_running_counter_offset_adjusted <= free_running_counter_drift_adjusted + offset_adjustment;
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        gtm_clk <= 1'b0;
        gtm_clk_en <= 1'b0;
    end else if (free_running_counter_offset_adjusted == cpu_init_toggle_time) begin
        gtm_clk <= ~gtm_clk;
        gtm_clk_en <= 1'b1;
    end else if (free_running_counter_offset_adjusted == cpu_prog_half_period_r) begin
        gtm_clk <= ~gtm_clk;
        gtm_clk_en <= 1'b0;
    end else begin
        gtm_clk_en <= 1'b0;
    end
end

endmodule

module broadsync_slave #(
    parameter BITCLK_TIMEOUT = 1024,
    parameter TIMEOUT_WIDTH = 64,
    parameter FRAC_NS_WIDTH = 30,
    parameter NS_WIDTH = 30,
    parameter S_WIDTH = 48
) (
    input  wire                        ptp_clk,
    input  wire                        ptp_reset,

    output reg                         lock_value,
    output reg  [S_WIDTH+NS_WIDTH+1:0] time_value,
    output reg  [7:0]                  clk_accuracy,
    output reg                         frame_error = 0,

    input  wire                        bitclock_in,
    input  wire                        heartbeat_in,
    input  wire                        timecode_in
);

localparam ACTIVE_WIDTH = S_WIDTH+NS_WIDTH+10;

reg                     lock = 1'b0;
reg  [ACTIVE_WIDTH-1:0] active = {ACTIVE_WIDTH{1'b0}};
reg  [7:0]              crc = {8{1'b1}};
wire [7:0]              crc_cal;

localparam START_WAIT  = TIMEOUT_WIDTH;
localparam ACTIVE_WAIT = ACTIVE_WIDTH;
localparam CRC_WAIT    = 8;
localparam DONE_WAIT   = TIMEOUT_WIDTH;

reg [31:0] count = {32{1'b0}};
reg [31:0] timeout = {32{1'b0}};

localparam IDLE   = 0;
localparam INIT   = 1;
localparam START  = 2;
localparam LOCK   = 3;
localparam ACTIVE = 4;
localparam CRC    = 5;
localparam DONE   = 6;
localparam UPDATE = 7;

reg [2:0] state = IDLE;

reg [3:0] bitclock_r;
reg [3:0] heartbeat_r;
reg [3:0] timecode_r;

wire gtm_clk_en = ~bitclock_r[3] && bitclock_r[2];
wire heartbeat_p = ~heartbeat_r[3] && heartbeat_r[2];
wire heartbeat_n = ~heartbeat_r[2] && heartbeat_r[3];

always @(posedge ptp_clk) begin
    bitclock_r  <= {bitclock_r[2:0],bitclock_in};
    heartbeat_r <= {heartbeat_r[2:0],heartbeat_in};
    timecode_r  <= {timecode_r[2:0],timecode_in};
end

always @(posedge ptp_clk) begin
    if (state == LOCK && gtm_clk_en) begin
        lock <= timecode_r[3];
    end
end

always @(posedge ptp_clk) begin
    if (state == ACTIVE && gtm_clk_en) begin
        active <= {active[ACTIVE_WIDTH-2:0],timecode_r[3]};
    end
end

always @(posedge ptp_clk) begin
    if (state == CRC && gtm_clk_en) begin
        crc <= {crc[6:0],timecode_r[3]};
    end
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        frame_error <= 0;
        lock_value <= 0;
        time_value <= 0;
        clk_accuracy <= 0;
    end else if (state == UPDATE && gtm_clk_en) begin
        if (crc == crc_cal) begin
            frame_error <= 0;
            lock_value <= lock;
            time_value <= active[ACTIVE_WIDTH-1:8];
            clk_accuracy <= active[7:0];
        end else begin
            frame_error <= 1;
        end
    end
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        state <= IDLE;
        count <= 0;
        timeout <= 0;
    end if (timeout >= BITCLK_TIMEOUT-1) begin
        timeout <= 0;
        state <= IDLE;
        count <= 0;
    end else if (gtm_clk_en) begin
        timeout <= 0;
        case (state)
            IDLE : begin
                if (heartbeat_p) begin
                    state <= INIT;
                end
                count <= 0;
            end
            INIT : begin
                if (~heartbeat_r[3]) begin
                    state <= IDLE;
                    count <= 0;
                end else if (~timecode_r[3] && timecode_r[2]) begin
                    state <= START;
                    count <= 0;
                end else if (count >= START_WAIT-1) begin
                    state <= IDLE;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            START : begin
                if (~heartbeat_r[3]) begin
                    state <= IDLE;
                end else begin
                    state <= LOCK;
                end
            end
            LOCK : begin
                if (~heartbeat_r[3]) begin
                    state <= IDLE;
                end else begin
                    state <= ACTIVE;
                end
            end
            ACTIVE : begin
                if (~heartbeat_r[3]) begin
                    state <= IDLE;
                    count <= 0;
                end else if (count >= ACTIVE_WAIT-1) begin
                    state <= CRC;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            CRC : begin
                if (~heartbeat_r[3]) begin
                    state <= IDLE;
                    count <= 0;
                end else if (count >= CRC_WAIT-1) begin
                    state <= DONE;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            DONE : begin
                if (~heartbeat_r[3]) begin
                    state <= IDLE;
                    count <= 0;
                end else if (heartbeat_n) begin
                    state <= UPDATE;
                    count <= 0;
                end else if (count >= DONE_WAIT-1) begin
                    state <= IDLE;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            UPDATE : begin
                state <= IDLE;
                count <= 0;
            end
            default : begin
                state <= IDLE;
                count <= 0;
            end
        endcase
    end else begin
        timeout <= timeout + 1;
    end
end

crc crc8_inst (
    .data_in ( timecode_r[3]   ) ,
    .crc_en  ( state == ACTIVE && gtm_clk_en ) ,
    .crc_out ( crc_cal         ) ,
    .rst     ( state == IDLE   ) ,
    .clk     ( ptp_clk         )
);

endmodule

module broadsync_master #(
    parameter TIMEOUT_WIDTH = 8,
    parameter FRAC_NS_WIDTH = 30,
    parameter NS_WIDTH = 30,
    parameter S_WIDTH = 48
) (
    input  wire                        ptp_clk,
    input  wire                        ptp_reset,

    input  wire                        gtm_clk,
    input  wire                        gtm_clk_en,
    input  wire                        frame_en,
    output reg                         frame_done,
    input  wire                        lock_value,
    input  wire [S_WIDTH+NS_WIDTH+1:0] time_value,
    input  wire [7:0]                  clk_accuracy,

    output wire                        bitclock_out,
    output reg                         heartbeat_out,
    output reg                         timecode_out
);

localparam ACTIVE_WIDTH = S_WIDTH+NS_WIDTH+10;

reg                     lock = 1'b0;
reg  [ACTIVE_WIDTH-1:0] active = {ACTIVE_WIDTH{1'b0}};
wire [7:0]              crc_cal;
reg  [7:0]              crc;

localparam INIT_WAIT   = TIMEOUT_WIDTH;
localparam ACTIVE_WAIT = ACTIVE_WIDTH;
localparam CRC_WAIT    = 8;
localparam DONE_WAIT   = TIMEOUT_WIDTH;

reg [31:0] count = {32{1'b0}};

localparam IDLE   = 0;
localparam INIT   = 1;
localparam START  = 2;
localparam LOCK   = 3;
localparam ACTIVE = 4;
localparam CRC    = 5;
localparam DONE   = 6;

reg [2:0] state = IDLE;

always @(posedge ptp_clk) begin
    if (state == IDLE && gtm_clk_en && frame_en) begin
        lock <= lock_value;
        active <= {time_value,clk_accuracy};
    end else if (state == ACTIVE && gtm_clk_en) begin
        active <= {active[ACTIVE_WIDTH-2:0],1'b0};
    end
end

always @(posedge ptp_clk) begin
    if (state == CRC && gtm_clk_en && count == 0) begin
        crc <= {crc_cal[6:0],1'b0};
    end else if (state == CRC && gtm_clk_en) begin
        crc <= {crc[6:0],1'b0};
    end
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        frame_done <= 1'b0;
    end else if (state == DONE && count >= DONE_WAIT-1) begin
        frame_done <= 1'b1;
    end else begin
        frame_done <= 1'b0;
    end
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        heartbeat_out <= 1'b0;
    end else if (state == IDLE) begin
        heartbeat_out <= 1'b0;
    end else begin
        heartbeat_out <= 1'b1;
    end
end

reg [1:0] gtm_clk_r = 2'd0;

always @(posedge ptp_clk) begin
    gtm_clk_r <= {gtm_clk_r[0],gtm_clk};
end

assign bitclock_out = gtm_clk_r[1];

always @(posedge ptp_clk) begin
    case (state)
        IDLE    : timecode_out <= 1'b0;
        INIT    : timecode_out <= 1'b0;
        START   : timecode_out <= 1'b1;
        LOCK    : timecode_out <= lock;
        ACTIVE  : timecode_out <= active[ACTIVE_WIDTH-1];
        CRC     : timecode_out <= count == 0 ? crc_cal[7] : crc[7];
        DONE    : timecode_out <= 1'b0;
        default : timecode_out <= 1'b0;
    endcase
end

always @(posedge ptp_clk) begin
    if (ptp_reset) begin
        state <= IDLE;
        count <= 0;
    end else if (gtm_clk_en) begin
        case (state)
            IDLE : begin
                if (frame_en) begin
                    state <= INIT;
                end
                count <= 0;
            end
            INIT : begin
                if (count >= INIT_WAIT-1) begin
                    state <= START;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            START : begin
                state <= LOCK;
            end
            LOCK : begin
                state <= ACTIVE;
            end
            ACTIVE : begin
                if (count >= ACTIVE_WAIT-1) begin
                    state <= CRC;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            CRC : begin
                if (count >= CRC_WAIT-1) begin
                    state <= DONE;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            DONE : begin
                if (count >= DONE_WAIT-1) begin
                    state <= IDLE;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            default : begin
                state <= IDLE;
                count <= 0;
            end
        endcase
    end
end

crc crc8_inst (
    .data_in ( timecode_out    ) ,
    .crc_en  ( state == ACTIVE && gtm_clk_en ) ,
    .crc_out ( crc_cal         ) ,
    .rst     ( state == IDLE   ) ,
    .clk     ( ptp_clk         )
);

endmodule
//-----------------------------------------------------------------------------
// CRC module for data[0:0] ,   crc[7:0]=1+x^4+x^5+x^8;
//-----------------------------------------------------------------------------
module crc(
    input [0:0] data_in,
    input crc_en,
    output [7:0] crc_out,
    input rst,
    input clk);

reg [7:0] lfsr_q,lfsr_c;

assign crc_out = lfsr_q;

always @(*) begin
    lfsr_c[0] = lfsr_q[7] ^ data_in[0];
    lfsr_c[1] = lfsr_q[0];
    lfsr_c[2] = lfsr_q[1];
    lfsr_c[3] = lfsr_q[2];
    lfsr_c[4] = lfsr_q[3] ^ lfsr_q[7] ^ data_in[0];
    lfsr_c[5] = lfsr_q[4] ^ lfsr_q[7] ^ data_in[0];
    lfsr_c[6] = lfsr_q[5];
    lfsr_c[7] = lfsr_q[6];
end

always @(posedge clk, posedge rst) begin
    if (rst) begin
        lfsr_q <= {8{1'b1}};
    end else begin
        lfsr_q <= crc_en ? lfsr_c : lfsr_q;
    end
end

endmodule
