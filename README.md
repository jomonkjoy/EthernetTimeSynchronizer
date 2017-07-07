# EthernetTimeSynchronizer

Ethernet Time Synchronization (ETS) for both physical layer and packet-based techniques that provide frequency and time-of-day synchronization across an Ethernet network.

## Register Description
| Name | Address | Description |
| --- | --- | --- |
| `frame_control_status` | 32'h00 | BroadSync frame enable for Master-bit[0], BroadSync frame valid from Slave-bit[31]  |
| `toggle_time_fractional_ns` | 32'h04 | CPU Initialized Toggle-Time fractional_ns[29:0] for generting GTM Clock output |
| `toggle_time_nanosecond` | 32'h08 | CPU Initialized Toggle-Time nanosecond[29:0] for generting GTM Clock output |
| `toggle_time_seconds_lsb` | 32'h0A | CPU Initialized Toggle-Time seconds[31:0] for generting GTM Clock output |
| `toggle_time_seconds_msb` | 32'h0C | CPU Initialized Toggle-Time seconds[47:32] for generting GTM Clock output |
| `half_period_fractional_ns` | 32'h10 | CPU Programmable Half-Period fractional_ns[29:0] for generting GTM Clock output |
| `time_offset_ns` | 32'h14 | CPU Programmable Time Offset nanosecond[29:0] for GTM free-running counter |
| `time_offset_s_lsb` | 32'h18 | CPU Programmable Time Offset seconds[31:0] for GTM free-running counter |
| `time_offset_s_msb` | 32'h1A | CPU Programmable Time Offset seconds[47:32] for GTM free-running counter |
| `lock_value_clk_accuracy_control` | 32'h1C | Configure {lock,clkAccuracy[7:0]} to BroadSync Master |
| `time_value_ns` | 32'h20 | Snapshot of OffsetAdjust nanosecond[29:0] from BroadSync Slave |
| `time_value_s_lsb` | 32'h24 | Snapshot of OffsetAdjust seconds[31:0] from BroadSync Slave |
| `time_value_s_msb` | 32'h28 | Snapshot of OffsetAdjust seconds[47:32] from BroadSync Slave |
| `frame_error_lock_value_clk_accuracy_status` | 32'h2C | Status of {FrameError,lock,clkAccuracy[7:0]} from BroadSync Slave |
