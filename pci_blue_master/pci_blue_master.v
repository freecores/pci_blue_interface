//===========================================================================
// $Id: pci_blue_master.v,v 1.1.1.1 2001-02-21 15:31:07 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The synthesizable pci_blue_interface PCI Master module.
//           This module takes commands from the Request FIFO and initiates
//           PCI activity based on the FIFO contents.  It reports progress
//           and error activity to the Target interface, which is in
//           control of the Response FIFO.
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
// NOTE:  This Master State Machine is an implementation of the Master State
//        Machine described in the PCI Local Bus Specification Revision 2.2,
//        Appendix B.  Locking is not supported.
//
// NOTE:  The Master State Machine must make sure that it can acept or
//        deliver data within the Master Data Latency time from when it
//        asserts FRAME Low, described in the PCI Local Bus Specification
//        Revision 2.2, section 3.5.2
//
// NOTE:  The Master State Machine has to concern itself with 2 timed events:
//        1) count down for master aborts, described in the PCI Local Bus
//           Specification Revision 2.2, section 3.3.3.1
//        2) count down Master Latency Timer when master, described in the
//           PCI Local Bus Specification Revision 2.2, section 3.5.4
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/10ps

module pci_blue_master (
// Signals driven to control the external PCI interface
  master_req_out,      master_gnt_now,
  pci_ad_in_prev,
  pci_master_ad_out_next,
  pci_master_ad_en_next, pci_master_ad_out_oe_comb,
  pci_cbe_l_out_next,
  pci_cbe_out_en_next, pci_cbe_out_oe_comb,
  pci_par_in_prev,     pci_par_in_comb,
  pci_master_par_out_next,
  pci_master_par_out_oe_comb,
  pci_frame_out_next,  pci_frame_out_oe_comb,
  pci_frame_in_prev,
  pci_irdy_out_next,   pci_irdy_out_oe_comb,
  pci_devsel_in_prev,  pci_devsel_in_comb,
  pci_trdy_in_prev,    pci_trdy_in_comb,
  pci_stop_in_prev,    pci_stop_in_comb,
  pci_perr_in_prev,
  pci_master_perr_out_next,
  pci_master_perr_out_oe_comb,
  pci_serr_in_prev,
  pci_master_serr_out_oe_comb,
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  pci_iface_request_type,
  pci_iface_request_cbe,
  pci_iface_request_data,
  pci_iface_request_data_available_meta,
  pci_iface_request_data_unload,
  pci_iface_request_error,
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  pci_master_to_target_request_type,
  pci_master_to_target_request_cbe,
  pci_master_to_target_request_data,
  pci_master_to_target_request_room_available_meta,
  pci_master_to_target_request_data_load,
  pci_master_to_target_request_error,
// Signals from the Master to the Target to set bits in the Status Register
  master_got_parity_error,
  master_caused_serr,
  master_got_master_abort,
  master_got_target_abort,
  master_caused_parity_error,
  master_enable,
  master_fast_b2b_en,
  master_perr_enable,
  master_serr_enable,
  master_latency_value,
  pci_clk,
  pci_reset_comb
);

// Signals driven to control the external PCI interface
  output  master_req_out;
  input   master_gnt_now;
  input  [31:0] pci_ad_in_prev;
  output [31:0] pci_master_ad_out_next;
  output  pci_master_ad_en_next;
  output  pci_master_ad_out_oe_comb;
  input  [3:0] pci_cbe_l_out_next;
  output  pci_cbe_out_en_next;
  output  pci_cbe_out_oe_comb;
  input   pci_par_in_prev;
  input   pci_par_in_comb;
  output  pci_master_par_out_next;
  output  pci_master_par_out_oe_comb;
  output  pci_frame_out_next;
  output  pci_frame_out_oe_comb;
  input   pci_frame_in_prev;
  output  pci_irdy_out_next;
  output  pci_irdy_out_oe_comb;
  input   pci_devsel_in_prev;
  input   pci_devsel_in_comb;
  input   pci_trdy_in_prev;
  input   pci_trdy_in_comb;
  input   pci_stop_in_prev;
  input   pci_stop_in_comb;
  input   pci_perr_in_prev;
  output  pci_master_perr_out_next;
  output  pci_master_perr_out_oe_comb;
  input   pci_serr_in_prev;
  output  pci_master_serr_out_oe_comb;
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  input  [2:0] pci_iface_request_type;
  input  [3:0] pci_iface_request_cbe;
  input  [31:0] pci_iface_request_data;
  input   pci_iface_request_data_available_meta;
  output  pci_iface_request_data_unload;
  input   pci_iface_request_error;
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  output [2:0] pci_master_to_target_request_type;
  output [3:0] pci_master_to_target_request_cbe;
  output [31:0] pci_master_to_target_request_data;
  input   pci_master_to_target_request_room_available_meta;
  output  pci_master_to_target_request_data_load;
  input   pci_master_to_target_request_error;
// Signals from the Master to the Target to set bits in the Status Register
  output  master_got_parity_error;
  output  master_caused_serr;
  output  master_got_master_abort;
  output  master_got_target_abort;
  output  master_caused_parity_error;
  input   master_enable;
  input   master_fast_b2b_en;
  input   master_perr_enable;
  input   master_serr_enable;
  input  [7:0] master_latency_value;
  input   pci_clk;
  input   pci_reset_comb;

  reg    [31:0] pci_master_data_out_next_reg;
  reg     pci_master_ad_out_oe_next_reg;
  reg    [3:0] pci_cbe_out_next_reg;
  reg    [3:0] pci_cbe_out_oe_next_reg;
  reg     pci_master_par_out_next_reg, pci_master_par_out_oe_next_reg;
  reg     pci_frame_out_next_reg, pci_frame_out_oe_next_reg;
  reg     pci_irdy_out_next_reg, pci_irdy_out_oe_next_reg;
  reg     pci_devsel_out_next_reg, pci_dts_out_oe_next_reg;
  reg     pci_trdy_out_next_reg;
  reg     pci_stop_out_next_reg;
  reg     pci_master_perr_out_next_reg, pci_master_perr_out_oe_next_reg;
  reg     pci_master_serr_out_oe_next_reg;
  reg     pci_req_out_next_reg;
  reg     pci_int_out_oe_next_reg;

// The Target State Machine has a pretty easy existence.  It responds
//   at leasure to the transition of FRAME_L from unasserted HIGH to
//   asserted LOW.
// It captures Write Data, but the data can be pipelined on the way
//   to the Receive Data Fifo.
// It delivers Read Data.  Here it must be snappy.  When IRDY_L and
//   TRDY_L are both asserted LOW, it must deliver new data the next
//   rising edge of the PCI clock.
// The Target State Machine ends a transfer when it sees FRAME_L go
//   HIGH again under control of the master, or whenever it wants under
//   ontrol of the slave.
// The PCI Bus Protocol lacks one important function, which is the
//   PCI Master deciding that it wants to terminate a transfer with
//   no more data.  This might happen if a PCI Master started a Burst
// Write, but changed it's mind after some data is transferred but
//   no more data is made available after a while.  The PCI Master
//   must always transfer a last data item to communicate end of burst.

// The state machine as described in Appendix B.
// No Lock State Machine is implemented.
// This design supports Medium Decode.  Fast Decode is not supported.

  parameter PCI_MASTER_IDLE        = 6'b000001;
  parameter PCI_MASTER_ADDR_B_BUSY = 6'b000010;
  parameter PCI_MASTER_M_DATA      = 6'b000100;
  parameter PCI_MASTER_S_TAR       = 6'b001000;
  parameter PCI_MASTER_TURN_AR     = 6'b010000;
  parameter PCI_MASTER_DR_BUS      = 6'b100000;
  reg [5:0] PCI_Master_State;
  wire [5:0] Next_PCI_Master_State;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
        if (pci_reset_comb)
            PCI_Master_State <= PCI_MASTER_IDLE;
        else
            PCI_Master_State <= Next_PCI_Master_State;
  end

  assign Next_PCI_Master_State[0] =     // MASTER_IDLE
        1'b0;
  assign Next_PCI_Master_State[1] =     // MASTER_IDLE
        1'b0;
  assign Next_PCI_Master_State[2] =     // MASTER_IDLE
        1'b0;
  assign Next_PCI_Master_State[3] =     // MASTER_IDLE
        1'b0;
  assign Next_PCI_Master_State[4] =     // MASTER_IDLE
        1'b0;
  assign Next_PCI_Master_State[5] =     // MASTER_IDLE
        1'b0;


// Experience with the PCI Master Interface teaches that the signals
//   FRAME and IRDY are extremely time critical.  These signals cannot be
//   latched in the IO pads.  The signals must be acted upon by the
//   Target State Machine as combinational inputs.

// This Case Statement is supposed to implement the Master State Machine.
// I believe that it might be safer to implement it as gates, in order
//   to make absolutely sure that there are the minimum number of loads on
//   the FRAME and IRDY signals.

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
        if (pci_reset_comb)
        begin
            PCI_Master_State <= PCI_MASTER_IDLE;
        end
        else
        begin
            case (PCI_Master_State)
            PCI_MASTER_IDLE:
              begin
              end
            PCI_MASTER_ADDR_B_BUSY:
              begin
              end
            PCI_MASTER_M_DATA:
              begin
              end
            PCI_MASTER_S_TAR:
              begin
              end
            PCI_MASTER_TURN_AR:
              begin
              end
            PCI_MASTER_DR_BUS:
              begin
              end

            default:
              begin
//                $display ("PCI Master State Machine Unknown %x at time %t",
//                            PCI_Master_State, $time);
              end
            endcase
        end
  end

  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
        if (pci_reset_comb)
        begin
            pci_master_ad_out_oe_next_reg <= 4'h0;
            pci_cbe_out_oe_next_reg[3:0] <= 4'h0;
            pci_master_par_out_oe_next_reg <= 1'b0;
            pci_frame_out_oe_next_reg <= 1'b0;
            pci_irdy_out_oe_next_reg <= 1'b0;
            pci_master_perr_out_oe_next_reg <= 1'b0;
            pci_master_serr_out_oe_next_reg <= 1'b0;
        end
        else
        begin
        end
  end

// NOTE WORKING
  assign  pci_master_ad_out_oe_comb = 1'b0;
  assign  pci_cbe_out_oe_comb = 1'b0;
  assign  pci_master_par_out_oe_comb = 1'b0;
  assign  pci_frame_out_oe_comb = 1'b0;
  assign  pci_irdy_out_oe_comb = 1'b0;
  assign  pci_master_perr_out_oe_comb = 1'b0;
  assign  pci_master_serr_out_oe_comb = 1'b0;

  assign  pci_master_to_target_request_data_load = 1'b0;
  assign  pci_iface_request_data_unload = 1'b0;

// Signals which the Target uses to determine what to do:
// Target_Address_Match
// Target_Retry
// Target_Disconnect_With_Data
// Target_Disconnect_Without_Data
// Target_Abort
// Target_Read_Fifo_Avail
// Target_Write_Fifo_Avail
// Some indication of timeout?

/* NOTE WORKING
  assign  pci_target_par_out_oe_next = pci_par_out_oe_next_reg;
  assign  pci_dts_out_oe_next = pci_dts_out_oe_next_reg;
  assign  pci_target_perr_out_oe_next = pci_perr_out_oe_next_reg;
  assign  pci_target_serr_out_oe_next = pci_serr_out_oe_next_reg;
*/

endmodule

