// cpu interface CDC from aclk to bclk
module cpu_if_cdc #( parameter SYNC_STAGE = 3 ) (
  input  logic        h_clk,
  input  logic        h_reset,

  output logic        h_cpu_if_read,
  output logic        h_cpu_if_write,
  output logic [31:0] h_cpu_if_write_data,
  output logic [31:2] h_cpu_if_address,
  input  logic [31:0] h_cpu_if_read_data,
  input  logic        h_cpu_if_access_complete,

  input  logic        l_clk,
  input  logic        l_reset,

  input  logic        l_cpu_if_read,
  input  logic        l_cpu_if_write,
  input  logic [31:0] l_cpu_if_write_data,
  input  logic [31:2] l_cpu_if_address,
  output logic [31:0] l_cpu_if_read_data,
  output logic        l_cpu_if_access_complete
);

endmodule
