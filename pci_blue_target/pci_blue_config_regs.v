//===========================================================================
// $Id: pci_blue_config_regs.v,v 1.7 2001-08-15 10:31:47 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  This file contains the PCI Blue Configuration Registers.
//           Many of these registers have fields which are exported as
//           wires and busses to the various Master and Target interface
//           logic which this interface controls.
//           These registers are byte-readable and byte-writable using
//           Config references from an external Master.
//           These registers are also readable and writable ONE-BYTE-
//           AT-A-TIME using special requests sent through the
//           Request FIFO.
//           NOTE: If there is no Master Interface, I don't know how
//           a processor on the Target side could change these registers.
//
// This library is free software; you can distribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published
// by the Free Software Foundation; either version 2.1 of the License, or
// (at your option) any later version.
//
// This library is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this library.  If not, write to
// Free Software Foundation, Inc.
// 59 Temple Place, Suite 330
// Boston, MA 02111-1307 USA
//
// Author's note about this license:  The intention of the Author and of
// the Gnu Lesser General Public License is that users should be able to
// use this code for any purpose, including combining it with other source
// code, combining it with other logic, translated it into a gate-level
// representation, or projected it into gates in a programmable or
// hardwired chip, as long as the users of the resulting source, compiled
// source, or chip are given the means to get a copy of this source code
// with no new restrictions on redistribution of this source.
//
// If you make changes, even substantial changes, to this code, or use
// substantial parts of this code as an inseparable part of another work
// of authorship, the users of the resulting IP must be given the means
// to get a copy of the modified or combined source code, with no new
// restrictions on redistribution of the resulting source.
//
// Separate parts of the combined source code, compiled code, or chip,
// which are NOT derived from this source code do NOT need to be offered
// to the final user of the chip merely because they are used in
// combination with this code.  Other code is not forced to fall under
// the GNU Lesser General Public License when it is linked to this code.
// The license terms of other source code linked to this code might require
// that it NOT be made available to users.  The GNU Lesser General Public
// License does not prevent this code from being used in such a situation,
// as long as the user of the resulting IP is given the means to get a
// copy of this component of the IP with no new restrictions on
// redistribution of this source.
//
// This code was developed using VeriLogger Pro, by Synapticad.
// Their support is greatly appreciated.
//
// NOTE:  The PCI Configuration Registers as described in the PCI Local
//        Bus Specification Revision 2.2, Chapter 6.
//
// NOTE:  This Configuration Register Set contains only 1 Base Address register.
//
//===========================================================================

`timescale 1ns/10ps

module pci_blue_config_regs (
  pci_config_write_data,
  pci_config_read_data,
  pci_config_address,
  pci_config_byte_enables,
  pci_config_write_req,
// Signals from the Config Registers to enable features in the Master and Target
  target_memory_enable,
  master_enable,
  either_perr_enable,
  either_serr_enable,
  master_fast_b2b_en,
  master_latency_value,
  base_register_0,
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
  base_register_1,
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
// Signals from the Master or the Target to set bits in the Status Register
  master_caused_parity_error,
  target_caused_abort,
  master_got_target_abort,
  master_caused_master_abort,
  either_caused_serr,
  either_got_parity_error,
// Courtesy indication that PCI Interface Config Register contains an error indication
  target_config_reg_signals_some_error,
  pci_clk,
  pci_reset_comb
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

// Signals driven to control the external PCI interface
  input  [31:0] pci_config_write_data;
  output [31:0] pci_config_read_data;
  input  [7:2] pci_config_address;
  input  [3:0] pci_config_byte_enables;
  input   pci_config_write_req;
// Signals from the Config Registers to enable features in the Master and Target
  output  target_memory_enable;
  output  master_enable;
  output  either_perr_enable;
  output  either_serr_enable;
  output  master_fast_b2b_en;
  output [7:0] master_latency_value;
  output [`PCI_BASE_ADDR0_MATCH_RANGE] base_register_0;
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
  output [`PCI_BASE_ADDR1_MATCH_RANGE] base_register_1;
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
// Signals from the Master or the Target to set bits in the Status Register
  input   master_caused_parity_error;
  input   target_caused_abort;
  input   master_got_target_abort;
  input   master_caused_master_abort;
  input   either_caused_serr;
  input   either_got_parity_error;
// Courtesy indication that PCI Interface Config Register contains an error indication
  output  target_config_reg_signals_some_error;
  input   pci_clk;
  input   pci_reset_comb;

// Configuration Registers.
// Addressed using A[7:2], PLUS 4 Byte Enables.
// Locations 0x00, 0x04, 0x08, 0x0C, 0x10, 0x3C, and optionally 0x14 will be
//   implemented as Control registers.
// All other locations will return 0x00.
// These registers are byte-enablable.  All Read and Write Data must be
//   properly aligned at the source.

// Config Register Area consists of:
//    31  24 23  16 15   8  7   0
//   |  Device ID  |  Vendor ID  | 0x00
//   |   Status    |   Command   | 0x04
//   |       Class Code   | Rev  | 0x08
//   | BIST | HEAD | LTCY | CSize| 0x0C
//   |      Base Address 0       | 0x10
//   |      Base Address 1       | 0x14
//   |          Unused           | 0x18
//   |          Unused           | 0x1C
//   |          Unused           | 0x20
//   |          Unused           | 0x24
//   |      Cardbus Pointer      | 0x28
//   |  SubSys ID  |  SubVnd ID  | 0x2C
//   |   Expansion ROM Pointer   | 0x30
//   |    Reserved        | Cap  | 0x34
//   |          Reserved         | 0x38
//   | MLat | MGnt | IPin | ILine| 0x3C
//
// Device ID, Vendor ID, Class Code, Rev Number, Min_Grane,
// and Max_Latency are defined in pci_blue_options.vh
//
// Command resets to 0x80.  It consists of:
// {6'h00, FB2B_En, SERR_En,
//  Step_En, Par_Err_En, VGA_En, Mem_Write_Inv_En,
//  Special_En, Master_En, Target_En, IO_En}
// Step_En is wired to 1.
// VGA_En is wired to 0.
// Mem_Write_Inv_En is wired to 0.
// SPecial_En is wired to 0.
// IO_En is wired to 0.
//
// Status consists of:
// {Detected_Perr, Signaled_Serr, Got_Master_Abort, Got_Target_Abort,
//  Signaled_Target_Abort, Devsel_Timing[1:0], Master_Got_Perr,
//  FB2B_Capable, 1'b0, 66MHz_Capable, New_Capabilities,
//  4'h0}
//
// Got_Master_Abort is not set for Special Cycles.
// Devsel will be 2'h01 in this design.  New_Capabilities is 1'b0.
// All clearable bits in this register are cleared whenever the
//   register is written with the corresponding bit being 1'b1.
// See the PCI Local Bus Spec Revision 2.2 section 6.2.3.

  reg     FB2B_En, SERR_En, Par_Err_En, Master_En, Target_Mem_En;
  reg     Detected_PERR, Signaled_SERR, Received_Master_Abort;
  reg     Received_Target_Abort, Signaled_Target_Abort, Master_Caused_PERR;
  reg    [7:0] Latency_Timer;
  reg    [7:0] Cache_Line_Size;
  reg    [7:0] Interrupt_Line;
  reg    [`PCI_BASE_ADDR0_MATCH_RANGE] BAR0;  // Base Address Registers, used to match addresses
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
  reg    [`PCI_BASE_ADDR1_MATCH_RANGE] BAR1;
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE

// Make a register transfer style Configuration Register, so it is easier to handle
//   simultaneous updates from the master and the target.
  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
    if (pci_reset_comb)
    begin
      FB2B_En <= 1'b0;
      SERR_En <= 1'b0;                Par_Err_En <= 1'b0;
      Master_En <= 1'b0;              Target_Mem_En <= 1'b0;
      Detected_PERR <= 1'b0;          Signaled_SERR <= 1'b0;
      Received_Master_Abort <= 1'b0;  Received_Target_Abort <= 1'b0;
      Signaled_Target_Abort <= 1'b0;  Master_Caused_PERR <= 1'b0;
      Latency_Timer[7:0]    <= 8'h00; Cache_Line_Size[7:0] <= 8'h00;
      Interrupt_Line[7:0]   <= 8'h00;
      BAR0[`PCI_BASE_ADDR0_MATCH_RANGE] <= `PCI_BASE_ADDR0_ALL_ZEROS;
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
      BAR1[`PCI_BASE_ADDR1_MATCH_RANGE] <= `PCI_BASE_ADDR1_ALL_ZEROS;
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
    end
    else
    begin
      if (pci_config_write_req)
      begin
// Words 0 and 2 are not writable.  Only certain bits in word 1 are writable.
        FB2B_En <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[1])
             ? ((pci_config_write_data[31:0] & CONFIG_CMD_FB2B_EN) != 32'h00000000)
             : FB2B_En;
        SERR_En <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[1])
             ? ((pci_config_write_data[31:0] & CONFIG_CMD_SERR_EN) != 32'h00000000)
             : SERR_En;
        Par_Err_En <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[0])
             ? ((pci_config_write_data[31:0] & CONFIG_CMD_PAR_ERR_EN) != 32'h00000000)
             : Par_Err_En;
        Master_En <=
               ((pci_config_address[7:2] == 6'h01) &~pci_config_byte_enables[0])
             ? ((pci_config_write_data[31:0] & CONFIG_CMD_MASTER_EN) != 32'h00000000)
             : Master_En;
        Target_Mem_En <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[0])
             ? ((pci_config_write_data[31:0] & CONFIG_CMD_TARGET_EN) != 32'h00000000)
             : Target_Mem_En;
// Certain bits in word 1 are only clearable, not writable.
        Detected_PERR <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[3]
                 & ((pci_config_write_data[31:0] & CONFIG_STAT_DETECTED_PERR) != 32'h00000000))
             ? 1'b0
             : Detected_PERR | either_got_parity_error;
        Signaled_SERR <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[3]
                 & ((pci_config_write_data[31:0] & CONFIG_STAT_DETECTED_SERR) != 32'h00000000))
             ? 1'b0
             : Signaled_SERR | either_caused_serr;
        Received_Master_Abort <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[3]
                 & ((pci_config_write_data[31:0] & CONFIG_STAT_GOT_MABORT) != 32'h00000000))
             ? 1'b0
             : Received_Master_Abort | master_caused_master_abort;
        Received_Target_Abort <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[3]
                 & ((pci_config_write_data[31:0] & CONFIG_STAT_GOT_TABORT) != 32'h00000000))
             ? 1'b0
             : Received_Target_Abort | master_got_target_abort;
        Signaled_Target_Abort <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[3]
                 & ((pci_config_write_data[31:0] & CONFIG_STAT_CAUSED_TABORT) != 32'h00000000))
             ? 1'b0
             : Signaled_Target_Abort | target_caused_abort;
        Master_Caused_PERR <=
               ((pci_config_address[7:2] == 6'h01) & pci_config_byte_enables[3]
                 & ((pci_config_write_data[31:0] & CONFIG_STAT_CAUSED_PERR) != 32'h00000000))
             ? 1'b0
             : Master_Caused_PERR | master_caused_parity_error;
// Certain bytes in higher words are writable
        Latency_Timer[7:0] <=
               ((pci_config_address[7:2] == 6'h03) & pci_config_byte_enables[1])
             ? pci_config_write_data[15:8]
             : Latency_Timer[7:0];
        Cache_Line_Size[7:0] <=
               ((pci_config_address[7:2] == 6'h03) & pci_config_byte_enables[0])
             ? pci_config_write_data[7:0]
             : Cache_Line_Size[7:0];
        BAR0[`PCI_BASE_ADDR0_MATCH_RANGE] <=
               ((pci_config_address[7:2] == 6'h04) & pci_config_byte_enables[3])
             ? pci_config_write_data[`PCI_BASE_ADDR0_MATCH_RANGE]
             : BAR0[`PCI_BASE_ADDR0_MATCH_RANGE];
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
        BAR1[`PCI_BASE_ADDR1_MATCH_RANGE] <=
               ((pci_config_address[7:2] == 6'h05) & pci_config_byte_enables[3])
             ? pci_config_write_data[`PCI_BASE_ADDR1_MATCH_RANGE]
             : BAR1[`PCI_BASE_ADDR1_MATCH_RANGE];
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
        Interrupt_Line[7:0] <=
               ((pci_config_address[7:2] == 6'h0F) & pci_config_byte_enables[0])
             ? pci_config_write_data[7:0]
             : Interrupt_Line[7:0];
      end
      else
      begin  // not writing from PCI side, either reading or doing nothing.
// Words 0 and 2 are not writable.  Only certain bits in word 1 are writable.
        FB2B_En    <= FB2B_En;
        SERR_En    <= SERR_En;        Par_Err_En     <= Par_Err_En;
        Master_En  <= Master_En;      Target_Mem_En  <= Target_Mem_En;
// Certain bits in word 1 are only clearable, not writable.
        Detected_PERR         <= Detected_PERR         | either_got_parity_error;
        Signaled_SERR         <= Signaled_SERR         | either_caused_serr;
        Received_Master_Abort <= Received_Master_Abort | master_caused_master_abort;
        Received_Target_Abort <= Received_Target_Abort | master_got_target_abort;
        Signaled_Target_Abort <= Signaled_Target_Abort | target_caused_abort;
        Master_Caused_PERR    <= Master_Caused_PERR    | master_caused_parity_error;
// Certain bytes in higher words are writable
        Latency_Timer[7:0]                <= Latency_Timer[7:0];
        Cache_Line_Size[7:0]              <= Cache_Line_Size[7:0];
        BAR0[`PCI_BASE_ADDR0_MATCH_RANGE] <= BAR0[`PCI_BASE_ADDR0_MATCH_RANGE];
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
        BAR1[`PCI_BASE_ADDR1_MATCH_RANGE] <= BAR1[`PCI_BASE_ADDR1_MATCH_RANGE];
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
        Interrupt_Line[7:0]               <= Interrupt_Line[7:0];
      end
    end
  end

// Combine bits to make Command and Status Registers for read-back
  wire   [15:0] Target_Command =
                     {4'b0000,
                      2'b00, FB2B_En, SERR_En,
                      1'b1, Par_Err_En, 2'b00,
                      1'b0, Master_En, Target_Mem_En, 1'b0};
  wire   [15:0] Target_Status =
                     {Detected_PERR, Signaled_SERR, Received_Master_Abort,
                                                    Received_Target_Abort,
                      Signaled_Target_Abort, 2'b01, Master_Caused_PERR,
                      1'b1, 1'b0,        // Fast Back-to-Back capable
`ifdef PCI_CLK_66
                                  1'b1,  // 66 MHz Status Bit
`else  // PCI_CLK_66
                                  1'b0,
`endif  // PCI_CLK_66
                                        1'b0,
                      4'b0000};

// Manually MUX all the Config Registers into the Read path.
// This used to be a function with a case statement in it, but I
// don't trust synthesis to do anything rational.
  wire   [31:0] config_read_data_4_0 = pci_config_address[2]
                  ? {Target_Status[15:0], Target_Command[15:0]}       // 4
                  : {PCI_DEVICE_ID, PCI_VENDOR_ID};                   // 0
  wire   [31:0] config_read_data_C_8 = pci_config_address[2]
                  ? {8'h00, PCI_HEAD_TYPE,
                      Latency_Timer[7:0], Cache_Line_Size[7:0]}       // C
                  : {PCI_CLASS_CODE, PCI_REV_NUM};                    // 8
  wire   [31:0] config_read_data_14_10 = pci_config_address[2]
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
                  ? {BAR1[`PCI_BASE_ADDR1_MATCH_RANGE],
                     `PCI_BASE_ADDR1_FILL, `PCI_BASE_ADDR1_MAP_QUAL}  // 14
`else  // PCI_BASE_ADDR1_MATCH_ENABLE
                  ? 32'h00000000                                      // 14
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
                  : {BAR0[`PCI_BASE_ADDR0_MATCH_RANGE],
                     `PCI_BASE_ADDR0_FILL, `PCI_BASE_ADDR0_MAP_QUAL}; // 10
  wire   [31:0] config_read_data_3C_38 = pci_config_address[2]
                  ? {PCI_MAX_LATENCY, PCI_MIN_GRANT,
                      8'h01, Interrupt_Line[7:0]}                     // 3C
                  : 32'h00000000;                                     // 38

  wire   [31:0] config_read_data_C_0 = pci_config_address[3]
                  ? config_read_data_C_8[31:0] : config_read_data_4_0[31:0];
  wire   [31:0] config_read_data_1C_10 = pci_config_address[3]
                  ? 32'h00000000 : config_read_data_14_10[31:0];
  wire   [31:0] config_read_data_3C_30 = pci_config_address[3]
                  ? config_read_data_3C_38[31:0] : 32'h00000000;

  wire   [31:0] config_read_data_1C_0 = pci_config_address[4]
                  ? config_read_data_1C_10[31:0] : config_read_data_C_0[31:0];
  wire   [31:0] config_read_data_3C_20 = pci_config_address[4]
                  ? config_read_data_3C_30[31:0] : 32'h00000000;

  wire   [31:0] config_read_data_3C_0 = pci_config_address[5]
                  ? config_read_data_3C_20[31:0] : config_read_data_1C_0[31:0];

  assign  pci_config_read_data[31:0] =
                   (pci_config_address[6] | pci_config_address[7])
                  ? 32'h00000000 : config_read_data_3C_0[31:0];

  assign  target_memory_enable = Target_Mem_En;
  assign  master_enable = Master_En;
  assign  either_perr_enable = Par_Err_En;
  assign  either_serr_enable = SERR_En;
  assign  master_fast_b2b_en = FB2B_En;
  assign  master_latency_value[7:0] = Latency_Timer[7:0];
  assign  base_register_0[`PCI_BASE_ADDR0_MATCH_RANGE] =
                                       BAR0[`PCI_BASE_ADDR0_MATCH_RANGE];
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
  assign  base_register_1[`PCI_BASE_ADDR1_MATCH_RANGE] =
                                       BAR1[`PCI_BASE_ADDR1_MATCH_RANGE];
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE

  assign  target_config_reg_signals_some_error = 
                  Detected_PERR | Signaled_SERR
                | Received_Master_Abort | Received_Target_Abort
                | Signaled_Target_Abort | Master_Caused_PERR;
endmodule

