//===========================================================================
// $Id: pci_blue_target.v,v 1.1.1.1 2001-02-21 15:31:23 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The synthesizable pci_blue_interface PCI Target module.
//           This module takes commands from the external PCI bus and
//           initiates on-chip SRAM reads and writes by writing information
//           in the Response FIFO.
//           All PCI Bus Initiated Reads are implemented as Delayed Reads.
//           After signaling a Delayed Read, this interface waits for a Write
//           Fence in the Request FIFO (or at least a pending Read) and also
//           for data in the Delayed Read Data FIFO.
//           If a Write collides with a Delayed Read in progress, all data in
//           the Delayed Read Data Fifo is flushed, and the SRAM Read is restarted.
//           This module also takes status information from the Master
//           module and returns it to the Host interface through the Response FIFO.
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
// NOTE:  This Target State Machine is an implementation of the Target State
//        Machine described in the PCI Local Bus Specification Revision 2.2,
//        Appendix B.
//
// NOTE:  This PCI interface will only respond to Type 0 Configuration
//        references, as described in the PCI Local Bus Specification
//        Revision 2.2, section 3.2.2.3.1, and Memory Read, Memory Read
//        Multiple, Memory Read Line, Memory Write, and Memory Write And
//        Invalidate commands, as described in the PCI Local Bus Specification
//        Revision 2.2, section 3.1.1
//        This interface does not bother to implement Interrupt, Special,
//        or IO references.
//
// NOTE:  This Target Interface stubs in Dual Address Cycles, but may not work.
//
// NOTE:  This PCI target will respond as a medium-speed device.  It will
//        be capable of handling fast back-to-back references.
//
// NOTE:  The Target State Machine has to concern itself with 2 timed events:
//        1) count down for Delayed Read Retrys
//        2) count down Delayed Read punts (follow-up read never came)
//
// NOTE:  The Target State Machine has to concern itself with the Target
//        Initial Latency and the Target Subsequent Latency, as described
//        in the PCI Local Bus Specification Revision 2.2, sections 3.5.1.1
//        and 3.5.1.2.
//
// NOTE:  This Target State Machine is prepared to try to deal with one
//        Delayed Read reference, , as described in the PCI Local Bus
//        Specification Revision 2.2, sections 3.3.3.3 and 3.7.5.
//
// NOTE:  This Target State Machine must be careful if an Address Parity
//        error is detected.  See the PCI Local Bus Specification Revision
//        2.2, section 3.7.3.
//
// NOTE:  This Target State Machine is aware that a write might occur while
//        a Delayed Read is begin done, and the write might hit on top of
//        prefetched read data.  This Target State Machine indicates the
//        possibility of data corruption to the host side of the interface.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/10ps

module pci_blue_target (
// Signals driven to control the external PCI interface
  pci_ad_in_prev,
  pci_target_ad_out_next,
  pci_target_ad_en_next, pci_target_ad_out_oe_comb,
  pci_idsel_in_prev,
  pci_cbe_l_in_prev,
  pci_par_in_prev,     pci_par_in_comb,
  pci_target_par_out_next,
  pci_target_par_out_oe_comb,
  pci_frame_in_prev,
  pci_irdy_in_prev,    pci_irdy_in_comb,
  pci_devsel_out_next, pci_d_t_s_out_oe_comb,
  pci_trdy_out_next,   pci_stop_out_next,
  pci_perr_in_prev,
  pci_target_perr_out_next,
  pci_target_perr_out_oe_comb,
  pci_serr_in_prev,
  pci_target_serr_out_oe_comb,
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  pci_iface_response_type,
  pci_iface_response_cbe,
  pci_iface_response_data,
  pci_iface_response_room_available_meta,
  pci_iface_response_data_load,
  pci_iface_response_error,
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  pci_iface_delayed_read_type,
  pci_iface_delayed_read_data,
  pci_iface_delayed_read_data_available_meta,
  pci_iface_delayed_read_data_unload,
  pci_iface_delayed_read_error,
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
// Courtesy indication that PCI Interface Config Register contains an error indication
  target_config_reg_signals_some_error,
  pci_clk,
  pci_reset_comb
);

// Signals driven to control the external PCI interface
  input  [31:0] pci_ad_in_prev;
  output [31:0] pci_target_ad_out_next;
  output  pci_target_ad_en_next;
  output  pci_target_ad_out_oe_comb;
  input   pci_idsel_in_prev;
  input  [3:0] pci_cbe_l_in_prev;
  input   pci_par_in_prev;
  input   pci_par_in_comb;
  output  pci_target_par_out_next;
  output  pci_target_par_out_oe_comb;
  input   pci_frame_in_prev;
  input   pci_irdy_in_prev;
  input   pci_irdy_in_comb;
  output  pci_devsel_out_next;
  output  pci_d_t_s_out_oe_comb;
  output  pci_trdy_out_next;
  output  pci_stop_out_next;
  input   pci_perr_in_prev;
  output  pci_target_perr_out_next;
  output  pci_target_perr_out_oe_comb;
  input   pci_serr_in_prev;
  output  pci_target_serr_out_oe_comb;
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  output [3:0] pci_iface_response_type;
  output [3:0] pci_iface_response_cbe;
  output [31:0] pci_iface_response_data;
  input   pci_iface_response_room_available_meta;
  output  pci_iface_response_data_load;
  input   pci_iface_response_error;
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  input  [2:0] pci_iface_delayed_read_type;
  input  [31:0] pci_iface_delayed_read_data;
  input   pci_iface_delayed_read_data_available_meta;
  output  pci_iface_delayed_read_data_unload;
  input   pci_iface_delayed_read_error;
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  input  [2:0] pci_master_to_target_request_type;
  input  [3:0] pci_master_to_target_request_cbe;
  input  [31:0] pci_master_to_target_request_data;
  output  pci_master_to_target_request_room_available_meta;
  input   pci_master_to_target_request_data_load;
  output  pci_master_to_target_request_error;
// Signals from the Master to the Target to set bits in the Status Register
  input   master_got_parity_error;
  input   master_caused_serr;
  input   master_got_master_abort;
  input   master_got_target_abort;
  input   master_caused_parity_error;
  output  master_enable;
  output  master_fast_b2b_en;
  output  master_perr_enable;
  output  master_serr_enable;
  output [7:0] master_latency_value;
// Courtesy indication that PCI Interface Config Register contains an error indication
  output  target_config_reg_signals_some_error;
  input   pci_clk;
  input   pci_reset_comb;

// NOTE WORKING temporarily set values to OE signals to let the bus not be X's
  assign  pci_target_ad_out_oe_comb = 1'b0;
  assign  pci_target_par_out_oe_comb = 1'b0;
  assign  pci_d_t_s_out_oe_comb = 1'b0;
  assign  pci_target_perr_out_oe_comb = 1'b0;
  assign  pci_target_serr_out_oe_comb = 1'b0;

  assign  pci_iface_response_data_load = 1'b0;
  assign  pci_iface_delayed_read_data_unload = 1'b0;

// Signals which the Target uses to determine what to do:
// Target_Address_Match
// Target_Retry
// Target_Disconnect_With_Data
// Target_Disconnect_Without_Data
// Target_Abort
// Target_Read_Fifo_Avail
// Target_Write_Fifo_Avail
// Some indication of timeout?

// temporary signals to control the IO pads, until real state machines are made.
  reg  [31:0] pci_data_out_next_prev;
  reg  [3:0] pci_data_out_step_oe_next_prev;
  reg  [3:0] pci_cbe_out_next_prev;
  reg  [3:0] pci_cbe_out_oe_next_prev;
  reg     pci_par_out_next_prev, pci_par_out_oe_next_prev;
  reg     pci_frame_out_next_prev, pci_frame_out_oe_next_prev;
  reg     pci_irdy_out_next_prev, pci_irdy_out_oe_next_prev;
  reg     pci_devsel_out_next_prev, pci_d_t_s_out_oe_next_prev;
  reg     pci_trdy_out_next_prev;
  reg     pci_stop_out_next_prev;
  reg     pci_perr_out_next_prev, pci_perr_out_oe_next_prev;
  reg     pci_serr_out_oe_next_prev;
  reg     pci_req_out_next_prev;
  reg     pci_int_out_oe_next_prev;

// Signals needed to implement delayed reads:
  reg [31:0] pci_delayed_read_address;
  reg [3:0] pci_delayed_read_command;
  reg     pci_delayed_read_address_parity;

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
//   control of the slave.
// The PCI Bus Protocol lacks one important function, which is the
//   PCI Master deciding that it wants to terminate a transfer with
//   no more data.  This might happen if a PCI Master started a Burst
//   Write, but changed it's mind after some data is transferred but
//   no more data is made available after a while.  The PCI Master
//   must always transfer a last data item to communicate end of burst.

// The state machine as described in Appendix B.
// No Lock State Machine is implemented.
// This design supports Medium Decode.  Fast Decode is not supported.

  parameter PCI_TARGET_IDLE    = 5'b00001;
  parameter PCI_TARGET_B_BUSY  = 5'b00010;
  parameter PCI_TARGET_S_DATA  = 5'b00100;
  parameter PCI_TARGET_BACKOFF = 5'b01000;
  parameter PCI_TARGET_TURN_AR = 5'b10000;
  reg [4:0] PCI_Target_State;
  wire [4:0] Next_PCI_Target_State;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
        if (pci_reset_comb)
            PCI_Target_State <= PCI_TARGET_IDLE;
        else
            PCI_Target_State <= PCI_Target_State;
  end

// Experience with the PCI Target interface teaches that the signals
//   FRAME and IRDY are extremely time critical.  These signals cannot be
//   latched in the IO pads.  The signals must be acted upon by the
//   Target State Machine as combinational inputs.

// This Case Statement is supposed to implement the Target State Machine.
//   I believe that it might be safer to implement it as gates, in order
//   to make absolutely sure that there are the minimum number of loads on
//   the FRAME and IRDY signals.
 
  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
        if (pci_reset_comb)
        begin
            PCI_Target_State <= PCI_TARGET_IDLE;
        end
        else
        begin
            case (PCI_Target_State)
            PCI_TARGET_IDLE:
              begin
              end
            PCI_TARGET_B_BUSY:
              begin
              end
            PCI_TARGET_S_DATA:
              begin
              end
            PCI_TARGET_BACKOFF:
              begin
              end
            PCI_TARGET_TURN_AR:
              begin
              end
            default:
              begin
 //               $display ("PCI Target State Machine Unknown %x at time %t",
 //                           PCI_Target_State, $time);
              end
            endcase
        end
  end

  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
        if (pci_reset_comb)
        begin
            pci_data_out_step_oe_next_prev <= 4'h0;
            pci_cbe_out_oe_next_prev <= 4'h0;
            pci_par_out_oe_next_prev <= 1'b0;
            pci_frame_out_oe_next_prev <= 1'b0;
            pci_irdy_out_oe_next_prev <= 1'b0;
            pci_d_t_s_out_oe_next_prev <= 1'b0;
            pci_perr_out_oe_next_prev <= 1'b0;
            pci_serr_out_oe_next_prev <= 1'b0;
            pci_int_out_oe_next_prev <= 1'b0;
        end
        else
        begin
        end
  end

//  assign  pci_d_t_s_out_oe_comb = pci_d_t_s_out_oe_next_prev;
//  assign  pci_target_perr_out_oe_comb = pci_perr_out_oe_next_prev;
//  assign  pci_target_serr_out_oe_comb = pci_serr_out_oe_next_prev;

endmodule

