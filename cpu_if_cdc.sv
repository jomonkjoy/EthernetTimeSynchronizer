// cpu interface CDC from aclk to bclk
// CDC with minimal logic read/write/access_complete needs to be pulse
// supports both high-to-low and low-to-high clocks
module cpu_if_cdc #( 
  parameter SYNC_STAGE = 3 
) (
  input  logic        h_clk,
  input  logic        h_reset,

  output logic        h_cpu_if_read,  // pulse
  output logic        h_cpu_if_write, // pulse
  output logic [31:0] h_cpu_if_write_data,
  output logic [31:2] h_cpu_if_address,
  input  logic [31:0] h_cpu_if_read_data,
  input  logic        h_cpu_if_access_complete, // pulse

  input  logic        l_clk,
  input  logic        l_reset,

  input  logic        l_cpu_if_read,  // pulse
  input  logic        l_cpu_if_write, // pulse
  input  logic [31:0] l_cpu_if_write_data,
  input  logic [31:2] l_cpu_if_address,
  output logic [31:0] l_cpu_if_read_data,
  output logic        l_cpu_if_access_complete // pulse
);
  
  logic access_type; // 0/1 = read/write
  logic access_request;
  logic access_complete;
  logic [31:0] cpu_if_write_data;
  logic [31:2] cpu_if_address;
  logic [31:0] cpu_if_read_data;
  // access type generation logic 0/1 = read/write
  always_ff @(posedge l_clk) begin
    if (l_reset) begin
      access_type <= 1'b0;
    end else if (l_cpu_if_write) begin
      access_type <= 1'b1;
    end else if (l_cpu_if_read) begin
      access_type <= 1'b0;
    end
  end
  // latch - address
  always_ff @(posedge l_clk) begin
    if (l_cpu_if_read|l_cpu_if_write) begin
      cpu_if_address <= l_cpu_if_address;
    end
  end
  // latch - write data
  always_ff @(posedge l_clk) begin
    if (l_cpu_if_write) begin
      cpu_if_write_data <= l_cpu_if_write_data;
    end
  end
  // synchronize access request-read/write
  data_sync_pulsegen #(
    .SYNC_STAGE (SYNC_STAGE)
  ) data_sync_pulsegen_req (
    .aclk(l_clk),
    .areset(l_reset),
    .adin(l_cpu_if_read|l_cpu_if_write), // pulse
    .aqualifier(),
    .bclk(h_clk),
    .bdout(access_request),// pulse
    .bqualifier()
  );
  assign h_cpu_if_read = access_request & ~access_type;
  assign h_cpu_if_write = access_request & access_type;
  assign h_cpu_if_write_data = cpu_if_write_data;
  assign h_cpu_if_address = cpu_if_address;
  // latch - read data
  always_ff @(posedge h_clk) begin
    if (h_cpu_if_access_complete) begin
      cpu_if_read_data <= h_cpu_if_read_data;
    end
  end
  // synchronize access compete
  data_sync_pulsegen #(
    .SYNC_STAGE (SYNC_STAGE)
  ) data_sync_pulsegen_ack (
    .aclk(h_clk),
    .areset(h_reset),
    .adin(h_cpu_if_access_complete), // pulse
    .aqualifier(),
    .bclk(l_clk),
    .bdout(access_complete),// pulse
    .bqualifier()
  );
  assign l_cpu_if_access_complete = access_complete;
  assign l_cpu_if_read_data = cpu_if_read_data;
  
endmodule
// Data-Sync : synchronize single-bit data
// Min 3 stage pipeline to mitegate metastability due to setup and hold time violations
// use ASYNC_REG and max_delay[with min-period(freq1,freq2)] constraint with async-clock groups {clk1,clk2}
module data_sync #(
  parameter SYNC_STAGE = 3
) (
  input  logic clk,
  input  logic din,
  output logic dout
);
  
  (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGE-1:0] sync_reg;
  always_ff @(posedge clk) begin
    sync_reg <= {sync_reg[SYNC_STAGE-2:0],din};
  end
  assign dout = sync_reg[SYNC_STAGE-1];
  
endmodule
// Data-Sync-pulsegen : synchronize singl-pulse from source_clk to destination_clk
module data_sync_pulsegen #(
  parameter SYNC_STAGE = 3
) (
  input  logic aclk,
  input  logic areset,
  input  logic adin, // pulse
  output logic aqualifier,
  input  logic bclk,
  output logic bdout,// pulse
  output logic bqualifier
);
  
  logic bqualifier_d;
  // qualifier signal generation using T-FF
  always_ff @(posedge aclk) begin
    if (areset) begin
      aqualifier <= 1'b0;
    end else begin
      aqualifier <= aqualifier ^ adin;
    end
  end
  // synchronize qualifier from aclk to bclk
  // 3-clock-cycle for a double-flop to get qualifier valid in bclk-domain
  data_sync #(
    .SYNC_STAGE (SYNC_STAGE)
  ) data_sync_qualifier (
    .clk  (bclk),
    .din  (aqualifier),
    .dout (bqualifier)
  );
  // pulse generation for each logic transition
  always_ff @(posedge bclk) begin
    bqualifier_d <= bqualifier;
  end
  assign bdout = bqualifier_d ^ bqualifier;
  
endmodule
