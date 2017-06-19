module broadsync_wrapper #(
    parameter BITCLK_TIMEOUT = 100*1024,
    parameter M_TIMEOUT_WIDTH = 8,
    parameter S_TIMEOUT_WIDTH = 64,
    parameter FRAC_NS_WIDTH = 30,
    parameter NS_WIDTH = 30,
    parameter S_WIDTH = 48
) (
    input  wire        ptp_clk,
    input  wire        ptp_reset,

    input  wire        bitclock_in,
    input  wire        heartbeat_in,
    input  wire        timecode_in,

    output wire        bitclock_out,
    output wire        heartbeat_out,
    output wire        timecode_out,

    input  wire        clk,
    input  wire        reset,

    input  wire        cpu_if_read,
    input  wire        cpu_if_write,
    input  wire [31:0] cpu_if_write_data,
    input  wire [31:2] cpu_if_address,
    output wire [31:0] cpu_if_read_data,
    output wire        cpu_if_access_complete
);

wire                        frame_en;
wire                        frame_done;
wire                        lock_value_in;
wire [7:0]                  clk_accuracy_in;
wire                        lock_value_out;
wire [S_WIDTH+NS_WIDTH+1:0] time_value_out;
wire [7:0]                  clk_accuracy_out;
wire                        frame_error;

wire [FRAC_NS_WIDTH-1:0]    toggle_time_fractional_ns;
wire [NS_WIDTH-1:0]         toggle_time_nanosecond;
wire [S_WIDTH-1:0]          toggle_time_seconds;
wire [FRAC_NS_WIDTH-1:0]    half_period_fractional_ns;
wire [NS_WIDTH-1:0]         half_period_nanosecond;
wire [FRAC_NS_WIDTH-0:0]    drift_rate;
wire [S_WIDTH+NS_WIDTH-0:0] time_offset;

wire                        csr_if_read;
wire                        csr_if_write;
wire [31:0]                 csr_if_write_data;
wire [31:2]                 csr_if_address;
wire [31:0]                 csr_if_read_data;
wire                        csr_if_access_complete;

cpu_if_cdc #( .SYNC_STAGE ( 3 ) ) cpu_if_cdc (
    .h_clk                     ( ptp_clk                   ) ,
    .h_reset                   ( ptp_reset                 ) ,

    .h_cpu_if_read             ( csr_if_read               ) ,
    .h_cpu_if_write            ( csr_if_write              ) ,
    .h_cpu_if_write_data       ( csr_if_write_data         ) ,
    .h_cpu_if_address          ( csr_if_address            ) ,
    .h_cpu_if_read_data        ( csr_if_read_data          ) ,
    .h_cpu_if_access_complete  ( csr_if_access_complete    ) ,

    .l_clk                     ( clk                       ) ,
    .l_reset                   ( reset                     ) ,

    .l_cpu_if_read             ( cpu_if_read               ) ,
    .l_cpu_if_write            ( cpu_if_write              ) ,
    .l_cpu_if_write_data       ( cpu_if_write_data         ) ,
    .l_cpu_if_address          ( cpu_if_address            ) ,
    .l_cpu_if_read_data        ( cpu_if_read_data          ) ,
    .l_cpu_if_access_complete  ( cpu_if_access_complete    )
);

broadsync_reg #(
    .FRAC_NS_WIDTH             ( FRAC_NS_WIDTH             ) ,
    .NS_WIDTH                  ( NS_WIDTH                  ) ,
    .S_WIDTH                   ( S_WIDTH                   ) 
) broadsync_reg (
    .clk                       ( ptp_clk                   ) ,
    .reset                     ( ptp_reset                 ) ,

    .frame_en                  ( frame_en                  ) ,
    .frame_done                ( frame_done                ) ,
    .lock_value_in             ( lock_value_in             ) ,
    .clk_accuracy_in           ( clk_accuracy_in           ) ,
    .lock_value_out            ( lock_value_out            ) ,
    .time_value_out            ( time_value_out            ) ,
    .clk_accuracy_out          ( clk_accuracy_out          ) ,
    .frame_error               ( frame_error               ) ,

    .toggle_time_fractional_ns ( toggle_time_fractional_ns ) ,
    .toggle_time_nanosecond    ( toggle_time_nanosecond    ) ,
    .toggle_time_seconds       ( toggle_time_seconds       ) ,
    .half_period_fractional_ns ( half_period_fractional_ns ) ,
    .half_period_nanosecond    ( half_period_nanosecond    ) ,
    .drift_rate                ( drift_rate                ) ,
    .time_offset               ( time_offset               ) ,

    .cpu_if_read               ( csr_if_read               ) ,
    .cpu_if_write              ( csr_if_write              ) ,
    .cpu_if_write_data         ( csr_if_write_data         ) ,
    .cpu_if_address            ( csr_if_address            ) ,
    .cpu_if_read_data          ( csr_if_read_data          ) ,
    .cpu_if_access_complete    ( csr_if_access_complete    ) 
);

broadsync_top #(
    .BITCLK_TIMEOUT            ( BITCLK_TIMEOUT            ) ,
    .M_TIMEOUT_WIDTH           ( M_TIMEOUT_WIDTH           ) ,
    .S_TIMEOUT_WIDTH           ( S_TIMEOUT_WIDTH           ) ,
    .FRAC_NS_WIDTH             ( FRAC_NS_WIDTH             ) ,
    .NS_WIDTH                  ( NS_WIDTH                  ) ,
    .S_WIDTH                   ( S_WIDTH                   ) 
) broadsync_top (
    .ptp_clk                   ( ptp_clk                   ) ,
    .ptp_reset                 ( ptp_reset                 ) ,

    .bitclock_in               ( bitclock_in               ) ,
    .heartbeat_in              ( heartbeat_in              ) ,
    .timecode_in               ( timecode_in               ) ,

    .bitclock_out              ( bitclock_out              ) ,
    .heartbeat_out             ( heartbeat_out             ) ,
    .timecode_out              ( timecode_out              ) ,

    .frame_en                  ( frame_en                  ) ,
    .frame_done                ( frame_done                ) ,
    .lock_value_in             ( lock_value_in             ) ,
    .clk_accuracy_in           ( clk_accuracy_in           ) ,
    .lock_value_out            ( lock_value_out            ) ,
    .time_value_out            ( time_value_out            ) ,
    .clk_accuracy_out          ( clk_accuracy_out          ) ,
    .frame_error               ( frame_error               ) ,

    .toggle_time_fractional_ns ( toggle_time_fractional_ns ) ,
    .toggle_time_nanosecond    ( toggle_time_nanosecond    ) ,
    .toggle_time_seconds       ( toggle_time_seconds       ) ,
    .half_period_fractional_ns ( half_period_fractional_ns ) ,
    .half_period_nanosecond    ( half_period_nanosecond    ) ,
    .drift_rate                ( drift_rate                ) ,
    .time_offset               ( time_offset               ) 
);

endmodule
