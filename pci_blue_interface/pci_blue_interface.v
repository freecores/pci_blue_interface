//===========================================================================
// $Id: pci_blue_interface.v,v 1.20 2001-07-23 09:43:40 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The top level of the pci_blue_interface.  This module
//           instantiates the Request, Response, and Delayed Read Data FIFOs,
//           as well as the synthesizable PCI Master and PCI Target interfaces.
//           No logic here.
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
// NOTE:  This interface is trying to be usable by different processor
//        and DMA masters.
//
//        One standard which this interface is trying to be usable by
//        is the Wishbone SOC bus.  This pci interface must function as
//        a Wishbone Target (initiating Master references on the PCI bus)
//        and as a Wishbone Master (acting in response to external PCI
//        master activity.)
//
//        The wishbone bus is a simple non-pipelined bus with a central
//        arbiter, masters, and slaves.  The on-chip bus will probably be
//        implemented as a balanced or trees to select the active address
//        and enables, and to convert individual data outputs into the single
//        shared data in bus.
//
//        A Wishbone Master will communicate with these wires:
//          CYC_O, a signal indicating that the bus is in use.  An arbitration signal.
//          ADR_O[N:0], the address.  We require that ADR_O[1:0] === 2'b00
//          SEL_O[3:0], byte strobes.  SEL_O[0] qualifies Data_X[7:0]
//          WE_O, asserted during Write references
//          Data_O[`PCI_FIFO_DATA_RANGE], and this interface expects [7:0] to be byte 0
//          Data_I[`PCI_FIFO_DATA_RANGE], and this interface expects [7:0] to be byte 0
//          STB_O, a strobe indicating that Address, SEL, WE, Write Data are valid
//          ACK_I, an indication that write data is consumed or read data available
//          RET_I, an indication that the Master should retry the reference.
//          ERR_I, an indication that a bus error occurred
//
// NOTE:  The PCI bus has many asserted-LOW signals.  However, to make
//        this interface simple, ALL SIGNALS ARE ASSERTED HIGH.  The
//        conversion to their external levels are done in the Pads.
//        One possible exception to this rule is the C_BE bus.
//
// NOTE TODO: Horrible.  Tasks can't depend on their Arguments being safe
//        if there are several instances ofthe task running at once.
//
// NOTE:  The writer of the FIFO must notice whether it is doing an IO reference
//        with the bottom 2 bits of the address not both 0.  If an IO reference
//        is done with at least 1 bit non-zero, the transfer must be a single
//        word transfer.  See the PCI Local Bus Specification Revision 2.2,
//        section 3.2.2.1 for details.
//
// NOTE:  The writer of the FIFO must only insert valid sequences of Request
//        entries.  Valid sequences are of the form Address->Data->Data_Last.
//        Writes can follow Writes immediately, without waiting for the first
//        to complete.  Write Fences happen after Data_Last and before Address
//        entries.
//
// NOTE:  The writer of the FIFO is responsible for following the Write Fence
//        protocol to ensure that the PCI ordering Rules are followed.  To
//        do things correctly when a Write Fence is requested, , the FIFO writer
//        must complete any writes, then either do a PCI Read or a Write Fence.
//        No other activity is allowed until the Write Fence is acknowledged.
//        Note that a Read will be acknowledged as a Write Fence!
//
// NOTE: WORKING: Very Subtle point.  The PCI Master may NOT look at the value
//        of signals it drove itself the previous clock.  The driver of a PCI bus
//        receives the value it drove later than all other devices.  See the PCI
//        Local Bus Spec Revision 2.2 section 3.10 item 9 for details.
//        FRAME isn't a problem, because it is driven 1 clock before IRDY.
//        This Master must therefore NOT look at IRDY unless it very sure that
//        the the data is constant for 2 clocks.  How?
//        This Master may not look at the Control wires from this Target, either.
//
//===========================================================================

`timescale 1ns/10ps

module pci_blue_interface (
// Coordinate Write_Fence with CPU
  pci_target_requests_write_fence, host_allows_write_fence,
// Host uses these wires to request PCI activity.
  pci_master_ref_address, pci_master_ref_command, pci_master_ref_config,
  pci_master_byte_enables_l, pci_master_write_data, pci_master_read_data,
  pci_master_addr_valid, pci_master_data_valid,
  pci_master_requests_serr, pci_master_requests_perr, pci_master_requests_last,
  pci_master_data_consumed, pci_master_ref_error,
// PCI Interface uses these wires to request local memory activity.   
  pci_target_ref_address, pci_target_ref_command,
  pci_target_byte_enables_l, pci_target_write_data, pci_target_read_data,
  pci_target_busy, pci_target_ref_start,
  pci_target_requests_abort, pci_target_requests_perr,
  pci_target_requests_disconnect,
  pci_target_data_transferred,
// PCI_Error_Report.
  pci_interface_reports_errors, pci_config_reg_reports_errors,
// Generic host interface wires
  pci_host_sees_pci_reset,
  host_reset_to_PCI_interface,
  host_clk, host_sync_clk,
// Wires used by the PCI State Machine and PCI Bus Combiner to drive the PCI bus
  pci_req_out_next,   pci_req_out_oe_comb,
  pci_gnt_in_prev,    pci_gnt_in_critical,
  pci_ad_in_prev,     pci_ad_out_next,     pci_ad_out_en_next,
                      pci_ad_out_oe_comb,
  pci_cbe_l_in_prev,  pci_cbe_l_in_critical,
                      pci_cbe_l_out_next,  pci_cbe_out_en_next,
                      pci_cbe_out_oe_comb,
  pci_par_in_prev,    pci_par_in_critical,
                      pci_par_out_next,    pci_par_out_oe_comb,
  pci_frame_in_prev,  pci_frame_in_critical,
                      pci_frame_out_next,  pci_frame_out_oe_comb,
  pci_irdy_in_prev,   pci_irdy_in_critical,
                      pci_irdy_out_next,   pci_irdy_out_oe_comb,
  pci_devsel_in_prev, pci_devsel_out_next, pci_d_t_s_out_oe_comb,
  pci_trdy_in_prev,   pci_trdy_in_critical,
                      pci_trdy_out_next,
  pci_stop_in_prev,   pci_stop_in_critical,
  pci_stop_out_next,
  pci_perr_in_prev,   pci_perr_out_next,   pci_perr_out_oe_comb,
  pci_serr_in_prev,                        pci_serr_out_oe_comb,
`ifdef PCI_EXTERNAL_IDSEL
  pci_idsel_in_prev,
`endif // PCI_EXTERNAL_IDSEL
  test_device_id,
  interface_error_event,
  pci_reset_comb,
  pci_clk, pci_sync_clk
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

// Coordinate Write_Fence with CPU
  output  pci_target_requests_write_fence;
  input   host_allows_write_fence;
// Host uses these wires to request PCI activity.
  input  [PCI_FIFO_DATA_RANGE:0] pci_master_ref_address;
  input  [3:0] pci_master_ref_command;
  input   pci_master_ref_config;
  input  [PCI_FIFO_CBE_RANGE:0] pci_master_byte_enables_l;
  input  [PCI_FIFO_DATA_RANGE:0] pci_master_write_data;
  output [PCI_FIFO_DATA_RANGE:0] pci_master_read_data;
  input   pci_master_addr_valid, pci_master_data_valid;
  input   pci_master_requests_serr, pci_master_requests_perr;
  input   pci_master_requests_last;
  output  pci_master_data_consumed;  // Host knows Data (and Address)
                                     // used when data_valid and data_consumed
  output  pci_master_ref_error;
// PCI Interface uses these wires to request local memory activity.   
  output [PCI_FIFO_DATA_RANGE:0] pci_target_ref_address;
  output [3:0] pci_target_ref_command;
  output [PCI_FIFO_CBE_RANGE:0] pci_target_byte_enables_l;
  output [PCI_FIFO_DATA_RANGE:0] pci_target_write_data;
  input  [PCI_FIFO_DATA_RANGE:0] pci_target_read_data;
  input   pci_target_busy;
  output  pci_target_ref_start;
  input   pci_target_requests_abort, pci_target_requests_perr;
  input   pci_target_requests_disconnect;
  input   pci_target_data_transferred;
// PCI_Error_Report.
  output [9:0] pci_interface_reports_errors;
  output  pci_config_reg_reports_errors;
// Generic host interface wires
  output  pci_host_sees_pci_reset;
  input   host_reset_to_PCI_interface;
  input   host_clk;
  input   host_sync_clk;  // used only by Synchronizers, and in Synthesis Constraints
// Wires used by the PCI State Machine and PCI Bus Combiner to drive the PCI bus
  output  pci_req_out_next;
  output  pci_req_out_oe_comb;
  input   pci_gnt_in_prev;
  input   pci_gnt_in_critical;
  input  [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  output [PCI_BUS_DATA_RANGE:0] pci_ad_out_next;
  output  pci_ad_out_en_next;
  output  pci_ad_out_oe_comb;
  input  [PCI_BUS_CBE_RANGE:0] pci_cbe_l_in_critical;
  input  [PCI_BUS_CBE_RANGE:0] pci_cbe_l_in_prev;
  output [PCI_BUS_CBE_RANGE:0] pci_cbe_l_out_next;
  output  pci_cbe_out_en_next;
  output  pci_cbe_out_oe_comb;
  input   pci_par_in_prev, pci_par_in_critical;
  output  pci_par_out_next, pci_par_out_oe_comb;
  input   pci_frame_in_prev, pci_frame_in_critical;
  output  pci_frame_out_next, pci_frame_out_oe_comb;
  input   pci_irdy_in_prev, pci_irdy_in_critical;
  output  pci_irdy_out_next, pci_irdy_out_oe_comb;
  input   pci_devsel_in_prev;
  output  pci_devsel_out_next, pci_d_t_s_out_oe_comb;
  input   pci_trdy_in_prev, pci_trdy_in_critical;
  output  pci_trdy_out_next;
  input   pci_stop_in_prev, pci_stop_in_critical;
  output  pci_stop_out_next;
  input   pci_perr_in_prev;
  output  pci_perr_out_next, pci_perr_out_oe_comb;
  input   pci_serr_in_prev;
  output                     pci_serr_out_oe_comb;
`ifdef PCI_EXTERNAL_IDSEL
  input   pci_idsel_in_prev;
`endif // PCI_EXTERNAL_IDSEL
  input  [2:0] test_device_id;
  output  interface_error_event;
  input   pci_reset_comb;
  input   pci_clk;
  input   pci_sync_clk;  // used only by Synchronizers, and in Synthesis Constraints

// Make temporary Bip every time an error is detected
  reg     interface_error_event;
  initial interface_error_event <= 1'bZ;
  reg     error_detected;
  initial error_detected <= 1'b0;
  always @(error_detected)
  begin
    interface_error_event <= 1'b0;
    #2;
    interface_error_event <= 1'bZ;
  end

// Double-synchronize the PCI Reset signal into the Host Clock Domain.  The PCI Reset
//   signal must be visible for at least two complete Host interface clocks.
  reg     pci_host_sees_pci_reset;
  wire    pci_reset_sync;
  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      pci_host_sees_pci_reset <= 1'b0;
    end
    else
    begin
      pci_host_sees_pci_reset <= pci_reset_sync;  // double-synchronize
    end
  end

// First level synchronization of PCI Reset signal
pci_synchronizer_flop sync_reset_flop (
  .data_in                    (pci_reset_comb),
  .clk_out                    (host_sync_clk),
  .sync_data_out              (pci_reset_sync),
  .async_reset                (host_reset_to_PCI_interface)
);

// Synchronization of signal which says PCI Interface sees some sort of error
  wire    target_config_reg_signals_some_error;
pci_synchronizer_flop sync_error_flop (
  .data_in                    (target_config_reg_signals_some_error),
  .clk_out                    (host_sync_clk),
  .sync_data_out              (pci_config_reg_signals_some_error),
  .async_reset                (host_reset_to_PCI_interface)
);

// Wires communicating between state machines here and FIFOs
// Wires used by the host controller to request action by the pci interface
  wire   [PCI_FIFO_DATA_RANGE:0] pci_host_request_data;
  wire   [PCI_FIFO_CBE_RANGE:0] pci_host_request_cbe;
  wire   [2:0] pci_host_request_type;
  wire    pci_host_request_room_available_meta;
  wire    pci_host_request_submit;
  wire    pci_host_request_error;
// Wires used by the pci interface to request action by the host controller
  wire   [PCI_FIFO_DATA_RANGE:0] pci_host_response_data;
  wire   [PCI_FIFO_CBE_RANGE:0] pci_host_response_cbe;
  wire   [3:0] pci_host_response_type;
  wire    pci_host_response_data_available_meta;
  wire    pci_host_response_unload;
  wire    pci_host_response_error;
// Wires used by the host controller to send delayed read data by the pci interface
  wire   [PCI_FIFO_DATA_RANGE:0] pci_host_delayed_read_data;
  wire   [2:0] pci_host_delayed_read_type;
  wire    pci_host_delayed_read_room_available_meta;
  wire    pci_host_delayed_read_data_submit;
  wire    pci_host_delayed_read_data_error;

// There are three Host Controller State Machines.
// The Host_Master_State_Machine is responsible for executing requests from the
//   Host to the PCI Bus.
// The Host_Target_State_Machine is responsible for executing requests from the
//   PCI Bus to the local Memory.
// The Host_Delayed_Read_State_Machine is responsible for requesting local memory
//   references.  It is also reponsibel for making certain that a "last" entry
//   is put in the Delayed Read FIFO in all cases.
//
// The Host_Target_State_Machine can ask the Host_Master_State_Machine to stick
//   a write fence into the Host Request FIFO in order to correctly implement
//   the PCI Ordering Rules.
// The Host_Target_State_Machine is also constantly sending info about the status
//   of Host-initiated PCI Activity back to the Host_Master_State_Machine.
// See the PCI Local Bus Spec Revision 2.2 section 3.3.3.3 for details.

// The Host_Master_State_Machine either directly executes the read or write if
//   it is to the local Memory, or it makes a request to the PCI Interface.
// A real Host Interface might not have to bother with issuing a Memory Reference
//   here, because it will have it's own port to the Memory and will never inform
//   the Host PCI Interface that it is doing a Memory reference.
// Writes are indicated to be done immediately.  Reads wait until the
//   data gets back before indicating done.
//
// Write Fences are used so that Delayed Read data comes out after all posted
//   writes are complete, and before writes done after the read are committed.
// The protocol is this:
// Host_Target_State_Machine asserts pci_target_requests_write_fence;
// Host Interface does as many writes as it wants.
//   The Delayed Read cannot complete during this period.
// Host Interface asserts host_allows_write_fence.
//   Host Interface holds off further writes while the Fence is in the pipe.
// Host_Master_State_Machine puts a Write Fence in the FIFO.
// Host_Master_State_Machine asserts master_issues_write_fence.
// Delayed Read state machine fetches and delivers data to external PCI Master.
// Host_Target_State_Machine deasserts pci_target_requests_write_fence.
// Host Interface can start writing again.
// If the request for a Write Fence comes in when the Host Interface is
//   waiting for the results of a Read, the first thing done after the
//   Read completes is to allow the Write Fence.  No writes are allowed
//   to occur after a read during which a Write Fence was requested.

  reg     pci_target_requests_write_fence;
  reg     master_issues_write_fence, target_sees_write_fence_end;

  parameter Example_Host_Master_Idle          = 3'b001;
  parameter Example_Host_Master_Transfer_Data = 3'b010;
  parameter Example_Host_Master_Read_Linger   = 3'b100;

  reg    [2:0] Example_Host_Master_State;

  wire    present_command_is_read =
            ((   pci_master_ref_command[3:0]
               & PCI_COMMAND_ANY_WRITE_MASK) == `PCI_FIFO_CBE_ZERO);
  wire    present_command_is_write = ~present_command_is_read;

  reg     target_sees_read_end;
  reg     master_ref_started, master_ref_done;

// Host_Master_State_Machine.  Operates when Host talks to external PCI devices
  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      master_ref_done <= 1'b0;
      master_issues_write_fence <= 1'b0;
      Example_Host_Master_State <= Example_Host_Master_Idle;
    end
    else
    begin
      case (Example_Host_Master_State[2:0])
      Example_Host_Master_Idle:
        begin
          if (pci_target_requests_write_fence & host_allows_write_fence)
          begin  // Issue Write Fence into FIFO, exclude other writes to FIFO
// Fence inserted if (~master_issues_write_fence & pci_host_request_room_available_meta)
            master_ref_done <= 1'b0;
            master_issues_write_fence <= pci_host_request_room_available_meta
                                       | master_issues_write_fence;
            Example_Host_Master_State <= Example_Host_Master_Idle;
$display ("Fence");  // NOTE WORKING
          end
          else if (pci_master_addr_valid & pci_master_ref_config)
          begin  // Issue Local PCI Register Command to PCI Controller
            if (~pci_host_request_room_available_meta | ~pci_master_data_valid)
            begin
              master_ref_done <= 1'b0;
              master_issues_write_fence <= 1'b0;
              Example_Host_Master_State <= Example_Host_Master_Idle;
$display ("Fence FIFOs Full");  // NOTE WORKING
            end
            else
            begin
              if (present_command_is_write)
              begin
                master_ref_done <= 1'b1;
                master_issues_write_fence <= 1'b0;
                Example_Host_Master_State <= Example_Host_Master_Idle;
$display ("Config Write");  // NOTE WORKING
              end
              else
              begin
                master_ref_done <= 1'b0;
                master_issues_write_fence <= 1'b0;
                Example_Host_Master_State <= Example_Host_Master_Read_Linger;
$display ("Config Read");  // NOTE WORKING
              end
            end
          end
          else if (pci_master_addr_valid & pci_host_request_room_available_meta)
          begin  // Issue Remote PCI Reference Address to PCI Controller
            master_ref_done <= 1'b0;
            master_issues_write_fence <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Transfer_Data;
$display ("Mem Address");  // NOTE WORKING
          end
          else
          begin  // No requests which can be acted on, so stay idle.
            master_ref_done <= 1'b0;
            master_issues_write_fence <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Idle;
          end
        end
      Example_Host_Master_Transfer_Data:
        begin
          if (~pci_host_request_room_available_meta | ~pci_master_data_valid)
          begin
            master_ref_done <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Transfer_Data;
$display ("Data FIFOs full");  // NOTE WORKING
          end
          else if (pci_master_requests_last & present_command_is_write)  // end of write
          begin
            master_ref_done <= 1'b1;
            Example_Host_Master_State <= Example_Host_Master_Idle;
$display ("Mem Write Last");  // NOTE WORKING
          end

          else if (pci_master_requests_last & present_command_is_read)  // end of read
          begin
            master_ref_done <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Read_Linger;
$display ("Mem Read Last");  // NOTE WORKING
          end
          else  // more data to transfer
          begin
            master_ref_done <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Transfer_Data;
$display ("Stay in Burst");  // NOTE WORKING
          end
          master_issues_write_fence <= 1'b0;  // not doing write fence, so never.
        end
      Example_Host_Master_Read_Linger:
        begin
          if (~target_sees_read_end)
          begin
            master_ref_done <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Read_Linger;
$display ("Waiting for Last Read Data");  // NOTE WORKING
          end
          else
          begin
            master_ref_done <= 1'b1;
            Example_Host_Master_State <= Example_Host_Master_Idle;
$display ("Got Last Read Data");  // NOTE WORKING
          end
          master_issues_write_fence <= 1'b0;  // not doing write fence, so never.
        end
      default:
        begin
          master_ref_done <= 1'b0;
          master_issues_write_fence <= 1'b0;
          Example_Host_Master_State <= Example_Host_Master_Idle;
          $display ("*** %m %h - Host_Master_State_Machine State invalid %b, at %t",
                      test_device_id[2:0],
                      Example_Host_Master_State[2:0], $time);
          error_detected <= ~error_detected;
        end
      endcase
    end
  end

// Create the funny fence-like message used to do local config references.
// Remember references to the local Config Registers can only be 1 byte at a time.
  wire   [7:0] config_ref_data =
                (~pci_master_byte_enables_l[0] ? pci_master_write_data[ 7: 0] : 8'h00)
              | (~pci_master_byte_enables_l[1] ? pci_master_write_data[15: 8] : 8'h00)
              | (~pci_master_byte_enables_l[2] ? pci_master_write_data[23:16] : 8'h00)
              | (~pci_master_byte_enables_l[3] ? pci_master_write_data[31:24] : 8'h00);
  wire   [1:0] config_ref_addr_lsb =
                (~pci_master_byte_enables_l[0] ? 2'h0
              : (~pci_master_byte_enables_l[1] ? 2'h1
              : (~pci_master_byte_enables_l[2] ? 2'h2
              : 2'h3)));

// Data for either a Write Fence, a Config Reference, the PCI Address, or the PCI Data.
// This is actually an if-then-else, done in combinational logic.  Would it be clearer as a function?
// A slower Host Interface could do this as sequential logic in an always block.
  assign  pci_host_request_data[PCI_FIFO_DATA_RANGE:0] =
                (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_target_requests_write_fence & host_allows_write_fence)
              ? {pci_master_ref_address[31:18], 2'b00, config_ref_data[7:0],
                 pci_master_ref_address[7:2], config_ref_addr_lsb[1:0]}
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_master_ref_config)
              ? {pci_master_ref_address[31:18], present_command_is_read,
                 present_command_is_write, config_ref_data[7:0],
                 pci_master_ref_address[7:2], config_ref_addr_lsb[1:0]}
              : ((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
              ? pci_master_ref_address[PCI_FIFO_DATA_RANGE:0]
              : pci_master_write_data[PCI_FIFO_DATA_RANGE:0])));  // Data advanced by host interface during burst

// Either the Host PCI Command or the Host Byte Enables.
  assign  pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0] =
             (Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
             ? pci_master_ref_command[PCI_FIFO_CBE_RANGE:0]
             : pci_master_byte_enables_l[PCI_FIFO_CBE_RANGE:0];  // Byte Enables advanced by host interface during burst

// Either Write Fence, Read/Write Config Register, Read/Write Address, Read/Write Data, Spare.
// This is actually an if-then-else, done in combinational logic.  Would it be clearer as a function?
// A slower Host Interface could do this as sequential logic in an always block.
  assign  pci_host_request_type[2:0] =
                (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_target_requests_write_fence & host_allows_write_fence)
              ? PCI_HOST_REQUEST_INSERT_WRITE_FENCE
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_master_ref_config)
              ? PCI_HOST_REQUEST_INSERT_WRITE_FENCE  // `PCI_HOST_REQUEST_READ_WRITE_CONFIG_REGISTER
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & ~pci_master_requests_serr)
              ? PCI_HOST_REQUEST_ADDRESS_COMMAND
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_master_requests_serr)
              ? PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & ~pci_master_requests_last & ~pci_master_requests_perr)
              ? PCI_HOST_REQUEST_W_DATA_RW_MASK
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & pci_master_requests_last & ~pci_master_requests_perr)
              ? PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & ~pci_master_requests_last & pci_master_requests_perr)
              ? PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & pci_master_requests_last & pci_master_requests_perr)
              ? PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR
              : PCI_HOST_REQUEST_SPARE))))))));

// Only write the FIFO when data is available and the FIFO has room for more data
// This is actually an if-then-else, done in combinational logic.  Would it be clearer as a function?
// A slower Host Interface could do this as sequential logic in an always block.
  assign  pci_host_request_submit =
                (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_target_requests_write_fence & host_allows_write_fence)
              ? (~master_issues_write_fence & pci_host_request_room_available_meta)
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & pci_master_ref_config)
              ? (  pci_master_addr_valid & pci_master_data_valid
                 & pci_host_request_room_available_meta)
              : ((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
              ? (pci_master_addr_valid & pci_host_request_room_available_meta)
              : ((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
              ? pci_host_request_room_available_meta
              : 1'b0))));

  assign  pci_master_data_consumed = pci_host_request_submit;

// Check for errors in the Host_Master_State_Machine
  always @(posedge host_clk)
  begin
    if (pci_master_addr_valid & pci_master_data_valid & ~master_ref_done
         &  pci_host_request_room_available_meta & pci_master_ref_config)
    begin
      if (~pci_master_requests_last)
      begin
        $display ("*** %m %h - Local Config Reg Refs must be exactly 1 word long, at %t",
                    test_device_id[2:0], $time);
        error_detected <= ~error_detected;
      end
      `NO_ELSE;
      if (  (pci_master_byte_enables_l[PCI_BUS_CBE_RANGE:0] != 4'hE)
          & (pci_master_byte_enables_l[PCI_BUS_CBE_RANGE:0] != 4'hD)
          & (pci_master_byte_enables_l[PCI_BUS_CBE_RANGE:0] != 4'hB)
          & (pci_master_byte_enables_l[PCI_BUS_CBE_RANGE:0] != 4'h7) )
      begin
        $display ("*** %m %h - Local Config Reg Refs must have exactly 1 Byte Enable %h, at %t",
                    test_device_id[2:0],
                    pci_master_byte_enables_l[PCI_BUS_CBE_RANGE:0], $time);
        error_detected <= ~error_detected;
      end
      `NO_ELSE;
    end
    `NO_ELSE;
    if (pci_host_request_error)
    begin
      $display ("*** %m %h - Request FIFO reports Error, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// Host_Target_State_Machine.
// The Host_Target_State_Machine executes PCI Bus references to the local Memory.
// The Host_Target_State_Machine can ask the Host_Master_State_Machine to stick
//   a write fence into the Host Request FIFO in order to correctly implement
//   the PCI Ordering Rules for Delayed Reads.  See the PCI Local Bus Spec
//   Revision 2.2 section 3.3.3.3 for details.
// This State Machine is responsible for restarting the Memory Read in the case
//   of a Delayed Read which is interrupted by a delayed write to the read region.
//
// This state machine seems to be mostly stateless.
// The two bits of state it keeps are that it requested a Write Fence but the
//   fence has not been sent yet, and that it requested a restart on an SRAM
//   read but the restart has not happened yet.
//
// This example Host Interface also checks the results of Master Reference here.
// Reads and Writes are tagged, and the information is encoded into the
//   middle 16 bits of the PCI Address.  The information is used at the end
//   of a PCI transfer to see if the expected activity occurred.
//
// There are two classes of entries in the Response FIFO.
// Response entries can be caused by progress being made in the Master
//   side of the interface, reflecting PCI activity initiated by this host.
// Response entries can be caused by references initiated by external PCI
//   Masters to this target interface.
// Most Response FIFO entries are control or documentation entries,
//   and can be dropped without action if the Host Interface isn't
//   recording everything to allow protocol violations.
// Certain Response FIFO entries can only be dropped after it is
//   assured that the Host Interface has acted on the data.  Specifically,
//   Address, Write Data, and Read Strobes from an external PCI Master
//   must be captured before the FIFO is unloaded.  Also, Read Data
//   returning as normal progress is being made to complete a Master-
//   initiated Read must be captured before it is dropped.
//
// This interface is trying to be High Performance.  It wants to handle
//   one FIFO entry every 2 processor clocks.  To achieve this, it must
//   be able to unload a FIFO entry as soon as it becomes available.
// This cannot be done in a state machine, because of the delays in the
//   FIFO Flag logic.  Instead, combinational logic below unloads the
//   FIFO depending on what the FIFO entry Type is, and also depending
//   on whether the Host Interface can capture the data right now.

// Capture signals needed to request the issuance of a Write Fence
//   into the Request FIFO.
// Forward references used to communicate with the Host_Master_State_Machine above:
//  reg     pci_target_requests_write_fence, target_sees_write_fence_end;

  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      pci_target_requests_write_fence <= 1'b0;
      target_sees_write_fence_end <= 1'b0;
    end
    else if (pci_host_response_data_available_meta)
    begin
      if (   (pci_host_response_type[3:0] ==
                  PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE)
           & ((   pci_host_response_cbe[PCI_FIFO_CBE_RANGE:0]
                & PCI_COMMAND_ANY_WRITE_MASK) == `PCI_FIFO_CBE_ZERO) )  // it's a read!
      begin
        pci_target_requests_write_fence <= 1'b1;
        target_sees_write_fence_end <= 1'b0;
      end
      else if (    (pci_host_response_type[3:0] ==
                                    PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE)
                 & (pci_host_response_data[17:16] == 2'b00) )
      begin
        pci_target_requests_write_fence <= 1'b0;
        target_sees_write_fence_end <= 1'b1;
      end
      else
      begin  // FIFO Command does not effect the Write Fence.  Just wait.
        pci_target_requests_write_fence <= pci_target_requests_write_fence
                                         & ~master_issues_write_fence;
        target_sees_write_fence_end <= 1'b0;
      end
    end
    else
    begin  // No command in FIFO.  Just wait.
      pci_target_requests_write_fence <= pci_target_requests_write_fence
                                       & ~master_issues_write_fence;
      target_sees_write_fence_end <= 1'b0;
    end
  end

// Capture signals to indicate that a Read is done to the Master State Machine above
// Forward references used to communicate with the Host_Master_State_Machine above:
//  reg     target_sees_read_end;
  reg     master_read_returning_data_now;

  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      master_read_returning_data_now <= 1'b0;
      target_sees_read_end <= 1'b0;
    end
    else if (pci_host_response_data_available_meta)
    begin
      if (pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXECUTED_ADDRESS_COMMAND)
      begin
        master_read_returning_data_now <=
          ((   pci_host_response_cbe[PCI_FIFO_CBE_RANGE:0]
             & PCI_COMMAND_ANY_WRITE_MASK) == `PCI_FIFO_CBE_ZERO);  // it's a read!
        target_sees_read_end <= 1'b0;
      end
      else if (master_read_returning_data_now
                & (pci_host_response_type[3:0] ==
                                 PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT) )
      begin
        if (   pci_host_response_data[29]    // Master_Abort_Received
             | pci_host_response_data[28] )  // Target_Abort_Received
        begin
          master_read_returning_data_now <= 1'b0;
          target_sees_read_end <= 1'b1;
        end
        else
        begin
          master_read_returning_data_now <= master_read_returning_data_now;
          target_sees_read_end <= 1'b0;
        end
      end
      else if (master_read_returning_data_now
                & (   (pci_host_response_type[3:0] ==
                                 PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST)
                    | (pci_host_response_type[3:0] ==
                                 PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR)
                    | (   (pci_host_response_type[3:0] ==
                                 PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE)
                        & pci_host_response_data[17]) ) )  // Config Read done
      begin
        master_read_returning_data_now <= 1'b0;
        target_sees_read_end <= 1'b1;
      end
      else
      begin  // FIFO Command does not effect the Master Read status.  Just wait.
        master_read_returning_data_now <= master_read_returning_data_now;
        target_sees_read_end <= 1'b0;
      end
    end
    else
    begin  // No command in FIFO.  Just wait.
      master_read_returning_data_now <= master_read_returning_data_now;
      target_sees_read_end <= 1'b0;
    end
  end

// Communication with the Host_Delayed_Read_State_Machine below:
  reg     delayed_read_start_requested, delayed_read_stop_seen;
  reg     delayed_read_flush_requested;
  reg     delayed_read_start_granted, delayed_read_flush_granted;

  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      delayed_read_start_requested <= 1'b0;
      delayed_read_stop_seen <= 1'b0;
      delayed_read_flush_requested <= 1'b0;
    end
    else if (pci_host_response_data_available_meta)
    begin
      if (   (pci_host_response_type[3:0] ==
                      PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE)
           & ((   pci_host_response_cbe[PCI_FIFO_CBE_RANGE:0]
                & PCI_COMMAND_ANY_WRITE_MASK) == `PCI_FIFO_CBE_ZERO) )  // it's a read!
      begin
        delayed_read_start_requested <= 1'b1;
        delayed_read_stop_seen <= 1'b0;
        delayed_read_flush_requested <= delayed_read_flush_requested
                                      & ~delayed_read_flush_granted;
      end
      else if (delayed_read_start_requested
                & (pci_host_response_type[3:0] ==
                      PCI_HOST_RESPONSE_EXT_DELAYED_READ_RESTART) )
      begin
        delayed_read_start_requested <= delayed_read_start_requested
                                      & ~delayed_read_start_granted;
        delayed_read_stop_seen <= 1'b0;
        delayed_read_flush_requested <= 1'b1;
      end
      else if (delayed_read_start_requested
                & (   (pci_host_response_type[3:0] ==
                             PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST)
                    | (pci_host_response_type[3:0] ==
                             PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR) ) )
      begin
        delayed_read_start_requested <= delayed_read_start_requested
                                      & ~delayed_read_start_granted;
        delayed_read_stop_seen <= 1'b1;
        delayed_read_flush_requested <= delayed_read_flush_requested
                                      & ~delayed_read_flush_granted;
      end
      else
      begin  // FIFO Command does not effect the Delayed Read status.  Just wait.
        delayed_read_start_requested <= delayed_read_start_requested
                                      & ~delayed_read_start_granted;
        delayed_read_stop_seen <= 1'b0;
        delayed_read_flush_requested <= delayed_read_flush_requested
                                      & ~delayed_read_flush_granted;
      end
    end
    else
    begin  // No command in FIFO.  Just wait.
      delayed_read_start_requested <= delayed_read_start_requested
                                    & ~delayed_read_start_granted;
      delayed_read_stop_seen <= 1'b0;
      delayed_read_flush_requested <= delayed_read_flush_requested
                                    & ~delayed_read_flush_granted;
    end
  end

// Capture signals needed to do local SRAM references
  reg    [PCI_FIFO_DATA_RANGE:0] Captured_Target_Address;
  reg    [3:0] Captured_Target_Type;
  reg     target_request_being_serviced;

  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      Captured_Target_Address[PCI_FIFO_DATA_RANGE:0] <=
                       Captured_Target_Address[PCI_FIFO_DATA_RANGE:0];
      Captured_Target_Type[PCI_FIFO_CBE_RANGE:0] <=
                       Captured_Target_Type[PCI_FIFO_CBE_RANGE:0];
      target_request_being_serviced <= target_request_being_serviced;
    end
    else
    begin
      if (pci_host_response_data_available_meta)
      begin  // NOTE WORKING
        Captured_Target_Address[PCI_FIFO_DATA_RANGE:0] <=
                         Captured_Target_Address[PCI_FIFO_DATA_RANGE:0];
        Captured_Target_Type[PCI_FIFO_CBE_RANGE:0] <=
                         Captured_Target_Type[PCI_FIFO_CBE_RANGE:0];
        target_request_being_serviced <= target_request_being_serviced;
      end
      else
      begin
        Captured_Target_Address[PCI_FIFO_DATA_RANGE:0] <=
                         Captured_Target_Address[PCI_FIFO_DATA_RANGE:0];
        Captured_Target_Type[PCI_FIFO_CBE_RANGE:0] <=
                         Captured_Target_Type[PCI_FIFO_CBE_RANGE:0];
        target_request_being_serviced <= target_request_being_serviced;
      end
    end
  end

// Capture signals needed to check Master reference results.
  reg    [PCI_FIFO_DATA_RANGE:0] Captured_Master_Address_Check;
  reg    [PCI_FIFO_CBE_RANGE:0] Captured_Master_Type_Check;
  reg     master_results_being_returned;

  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      Captured_Master_Address_Check[PCI_FIFO_DATA_RANGE:0] <=
                          Captured_Master_Address_Check[PCI_FIFO_DATA_RANGE:0];
      Captured_Master_Type_Check[PCI_FIFO_CBE_RANGE:0] <=
                          Captured_Master_Type_Check[PCI_FIFO_CBE_RANGE:0];
      master_results_being_returned <= 1'b0;
    end
    else
    begin
      if (pci_host_response_data_available_meta)
      begin  // NOTE WORKING
        Captured_Master_Address_Check[PCI_FIFO_DATA_RANGE:0] <=
                            Captured_Master_Address_Check[PCI_FIFO_DATA_RANGE:0];
        Captured_Master_Type_Check[PCI_FIFO_CBE_RANGE:0] <=
                            Captured_Master_Type_Check[PCI_FIFO_CBE_RANGE:0];
        master_results_being_returned <= master_results_being_returned;
      end
      else
      begin
        Captured_Master_Address_Check[PCI_FIFO_DATA_RANGE:0] <=
                         Captured_Master_Address_Check[PCI_FIFO_DATA_RANGE:0];
        Captured_Master_Type_Check[PCI_FIFO_CBE_RANGE:0] <=
                         Captured_Master_Type_Check[PCI_FIFO_CBE_RANGE:0];
        master_results_being_returned <= master_results_being_returned;
      end
    end
  end

// Capture Error bits in Host Status Register.
  reg    [9:0] pci_interface_reports_errors;
  always @(posedge host_clk)
  begin
    if (pci_host_response_data_available_meta)
    begin
      if (   ((pci_host_response_type[3:0] ==
                            PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT)
                & pci_host_response_data[31])
           | (pci_host_response_type[3:0] ==
                            PCI_HOST_RESPONSE_R_DATA_W_SENT_PERR)
           | (pci_host_response_type[3:0] ==
                            PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR)
           | (pci_host_response_type[3:0] ==
                            PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_PERR)
           | (pci_host_response_type[3:0] ==
                            PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR) )
      begin
        pci_interface_reports_errors[9] <= 1'b1;  // PERR_Detected
      end
      else
      begin
        pci_interface_reports_errors[9] <= 1'b0;
      end

      if (pci_host_response_type[3:0] ==
                         PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT)
      begin
        pci_interface_reports_errors[8] <= pci_host_response_data[30];  // SERR_Detected
        pci_interface_reports_errors[7] <= pci_host_response_data[29];  // Master_Abort_Received
        pci_interface_reports_errors[6] <= pci_host_response_data[28];  // Target_Abort_Received
        pci_interface_reports_errors[5] <= pci_host_response_data[27];  // Caused_Target_Abort
        pci_interface_reports_errors[4] <= pci_host_response_data[24];  // Caused_PERR
        pci_interface_reports_errors[3] <= pci_host_response_data[18];  // Discarded_Delayed_Read
        pci_interface_reports_errors[2] <= pci_host_response_data[17];  // Target_Retry_Or_Disconnect
        pci_interface_reports_errors[1] <= pci_host_response_data[16];  // Illegal_Command_Detected_In_Request_FIFO
      end
      else
      begin
        pci_interface_reports_errors[8:1] <= 8'h00;
      end
      pci_interface_reports_errors[0] <=  // Illegal_Command_Detected_In_Response_FIFO
         (pci_host_response_type[3:0] == PCI_HOST_RESPONSE_SPARE);
    end
    else
    begin
      pci_interface_reports_errors[9:0]= 10'h000;
    end
  end

// NOTE WORKING Need to get rid of that 1'b0
// Unload Response FIFO when it is possible to pass its contents to all interested parties.
  assign  pci_host_response_unload = 1'b0 & (pci_host_response_data_available_meta
             & (   ((pci_host_response_type[3:0] == PCI_HOST_RESPONSE_SPARE))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXECUTED_ADDRESS_COMMAND))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT))
                 | ((pci_host_response_type[3:0] ==// PCI_HOST_RESPONSE_READ_WRITE_CONFIG_REGISTER
                                   PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_R_DATA_W_SENT))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_R_DATA_W_SENT_PERR))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR))
                 | ((pci_host_response_type[3:0] ==
                        PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE))  // wait!
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXT_DELAYED_READ_RESTART))  // wait!
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXT_READ_UNSUSPENDING))
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK))  // wait!
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST))  // wait!
                 | ((pci_host_response_type[3:0] ==
                                   PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_PERR))  // wait!
                 | ((pci_host_response_type[3:0] ==
                               PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR))   // wait!
               ) );


/*
        `PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE:
// also `PCI_HOST_RESPONSE_READ_WRITE_CONFIG_REGISTER
// A write fence unload response will have Bits 16 and 17 both set to 1'b0.
// Config References can be identified by noticing that Bits 16 or 17 are non-zero.
// Data Bits [7:0] are the Byte Address of the Config Register being accessed.
// Data Bits [15:8] are the single-byte Read Data returned when writing the Config Register.
// Data Bit  [16] indicates that a Config Write has been done.
// Data Bit  [17] indicates that a Config Read has been done.
        `PCI_HOST_RESPONSE_R_DATA_W_SENT:
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST:
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_PERR:
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR:
        `PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE:
        `PCI_HOST_RESPONSE_EXT_DELAYED_READ_RESTART:
        `PCI_HOST_RESPONSE_EXT_READ_UNSUSPENDING:
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK:
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST:
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_PERR:
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR:
*/

// NOTE: WORKING
// Get the next Host Data during a Burst.  In this example Host Interface,
//   data always increments by 32'h01010101 during a burst.
// The Write side increments it during writes, and the Read side increments
// it during compares.
  wire    Calculate_Next_Host_Data_During_Reads = 1'b0;

// Check for errors in the Host_Target_State_Machine
  always @(posedge host_clk)
  begin
    if (   pci_host_response_data_available_meta
         & ((^pci_host_response_type[3:0]) === 1'bX))
    begin
      $display ("*** %m %h - Host_Target_State_Machine FIFO Type invalid %b, at %t",
                  test_device_id[2:0], pci_host_response_type[3:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (pci_host_response_error)
    begin
      $display ("*** %m %h - Response FIFO reports Error, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// Get the next Host Data during a Burst.  In this example Host Interface,
//   data always increments by 32'h01010101 during a burst.
// Only master-initiated transfers are checked for correctness.  To check that
//   data is written correctly to a remote PCI device, read it back!
// The Write side increments it during writes, and the Read side increments
//   it during compares.
//  assign  pci_master_data_transferred = Offer_Next_Host_Data_During_Writes
//                                     | Calculate_Next_Host_Data_During_Reads;
  assign  pci_master_ref_error = 1'b0;  // NOTE WORKING

// Host_Delayed_Read_State_Machine
// This state machine is given an address by the Host_Response_FIFO.
// One of two things can happen.
//   1) Interface knows all data is prefetchable, so this starts reading immediately.
//   2) Interface knows that data is NOT prefetchable, so this waits until the
//      Byte Enables arrive fron the external PCI Master.
//      If this state machine is lucky, it notices that only a single-word
//      Read is being done, so it does not waste memory bandwidth by
//      fetching data the remote PCI Master.
//
// This state machine gets notice from the Response FIFO State Machine that
//   the External PCI Master has requested it's last data.  If this state
//   machine is pre-fetching, it should stop and insert a last data item
//   into the prefetch FIFO.
// This state machine must ALWAYS insert a last data item whenever it is
//   asked to restart a transfer (even if no real data has been transfered)
//   and when the external PCI Target finishes it's burst.  This is because
//   the PCI Interface will flush the FIFO until it sees a last data item.

  reg     target_ref_start;
  reg     target_ref_size;
  reg    [PCI_FIFO_DATA_RANGE:0] target_ref_address;
  reg    [3:0] target_ref_command;
  reg    [PCI_FIFO_CBE_RANGE:0] target_byte_enables_l;
  reg    [PCI_FIFO_DATA_RANGE:0] target_write_data;

  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      target_ref_start <= 1'b0;
      target_write_data[PCI_FIFO_DATA_RANGE:0] <= `PCI_FIFO_DATA_ZERO;
      target_ref_address[5:0] <= 6'h00;
      target_byte_enables_l[PCI_FIFO_CBE_RANGE:0] <= `PCI_FIFO_CBE_F;
    end
    else
    begin
      if (pci_host_delayed_read_room_available_meta)
      begin
      end
    end
  end

// NOTE WORKING
  assign  pci_host_delayed_read_data[PCI_FIFO_DATA_RANGE:0] = `PCI_FIFO_DATA_ZERO;
  assign  pci_host_delayed_read_type[2:0] = PCI_HOST_DELAYED_READ_DATA_SPARE;
  assign  pci_host_delayed_read_data_submit = 1'b0;

// Check for errors in the Host_Target_State_Machine
  always @(posedge host_clk)
  begin
    if (pci_host_delayed_read_data_error)
    begin
      $display ("*** %m %h - Delayed Read FIFO reports Error, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// Wires connecting the Host FIFOs to the PCI Interface
  wire   [2:0] pci_request_fifo_type;
  wire   [PCI_FIFO_CBE_RANGE:0] pci_request_fifo_cbe;
  wire   [PCI_FIFO_DATA_RANGE:0] pci_request_fifo_data;
  wire    pci_request_fifo_data_available_meta;
  wire    pci_request_fifo_two_words_available_meta;
  wire    pci_request_fifo_data_unload;
  wire    pci_request_fifo_error;
  wire   [3:0] pci_response_fifo_type;
  wire   [PCI_FIFO_CBE_RANGE:0] pci_response_fifo_cbe;
  wire   [PCI_FIFO_DATA_RANGE:0] pci_response_fifo_data;
  wire    pci_response_fifo_room_available_meta;
  wire    pci_response_fifo_data_load, pci_response_fifo_error;
  wire   [2:0] pci_delayed_read_fifo_type;
  wire   [PCI_FIFO_DATA_RANGE:0] pci_delayed_read_fifo_data;
  wire    pci_delayed_read_fifo_data_available_meta;
  wire    pci_delayed_read_fifo_data_unload, pci_delayed_read_fifo_error;
 
// Instantiate the Host_Request_FIFO, from the Host to the PCI Interface
pci_fifo_storage_request pci_fifo_storage_request (
  .reset_flags_async          (host_reset_to_PCI_interface),
// Mode 2`b01 means write data, then update flag, read together
  .fifo_mode                  (2'b01),
  .write_clk                  (host_clk),
  .write_sync_clk             (host_sync_clk),
  .write_submit               (pci_host_request_submit),
// NOTE Needs extra settling time to avoid metastability
  .write_room_available_meta  (pci_host_request_room_available_meta),
  .write_data                 ({pci_host_request_type[2:0],
                                pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0],
                                pci_host_request_data[PCI_FIFO_DATA_RANGE:0]}),
  .write_error                (pci_host_request_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_sync_clk),
  .read_remove                (pci_request_fifo_data_unload),
// NOTE Needs extra settling time to avoid metastability
  .read_data_available_meta   (pci_request_fifo_data_available_meta),
// NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (pci_request_fifo_two_words_available_meta),
  .read_data                  ({pci_request_fifo_type[2:0],
                                pci_request_fifo_cbe[PCI_FIFO_CBE_RANGE:0],
                                pci_request_fifo_data[PCI_FIFO_DATA_RANGE:0]}),
  .read_error                 (pci_request_fifo_error)
);

// Instantiate the Host_Response_FIFO, from the PCI Interface to the Host
pci_fifo_storage_response pci_fifo_storage_response (
  .reset_flags_async          (host_reset_to_PCI_interface),
// Mode 2`b10 means write together, read flag, then read data
  .fifo_mode                  (2'b10),
  .write_clk                  (pci_clk),
  .write_sync_clk             (pci_sync_clk),
  .write_submit               (pci_response_fifo_data_load),
// NOTE Needs extra settling time to avoid metastability
  .write_room_available_meta  (pci_response_fifo_room_available_meta),
  .write_data                 ({pci_response_fifo_type[3:0],
                                pci_response_fifo_cbe[PCI_FIFO_CBE_RANGE:0],
                                pci_response_fifo_data[PCI_FIFO_DATA_RANGE:0]}),
  .write_error                (pci_response_fifo_error),
  .read_clk                   (host_clk),
  .read_sync_clk              (host_sync_clk),
  .read_remove                (pci_host_response_unload),
// NOTE Needs extra settling time to avoid metastability
  .read_data_available_meta   (pci_host_response_data_available_meta),
// NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (),  // NOTE: WORKING
  .read_data                  ({pci_host_response_type[3:0],
                                pci_host_response_cbe[PCI_FIFO_CBE_RANGE:0],
                                pci_host_response_data[PCI_FIFO_DATA_RANGE:0]}),
  .read_error                 (pci_host_response_error)
);

// Instantiate the Host_Delayed_Read_Data_FIFO, from the Host to the PCI Interface
pci_fifo_storage_delayed_read pci_fifo_storage_delayed_read (
  .reset_flags_async          (host_reset_to_PCI_interface),
// Mode 2`b01 means write data, then update flag, read together
  .fifo_mode                  (2'b01),
  .write_clk                  (host_clk),
  .write_sync_clk             (host_sync_clk),
  .write_submit               (pci_host_delayed_read_data_submit),
// NOTE Needs extra settling time to avoid metastability
  .write_room_available_meta  (pci_host_delayed_read_room_available_meta),
  .write_data                 ({pci_host_delayed_read_type[2:0],
                                pci_host_delayed_read_data[PCI_FIFO_DATA_RANGE:0]}), 
  .write_error                (pci_host_delayed_read_data_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_sync_clk),
  .read_remove                (pci_delayed_read_fifo_data_unload),
// NOTE Needs extra settling time to avoid metastability
  .read_data_available_meta   (pci_delayed_read_fifo_data_available_meta),
// NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (),  // NOTE: WORKING
  .read_data                  ({pci_delayed_read_fifo_type[2:0],
                                pci_delayed_read_fifo_data[PCI_FIFO_DATA_RANGE:0]}), 
  .read_error                 (pci_delayed_read_fifo_error)
);

// Target signals to be combined with Master signals on the way to the PCI IO Pads.
  wire   [PCI_BUS_DATA_RANGE:0] pci_target_ad_out_next;
  wire    pcu_target_ad_en_next,    pci_target_ad_out_oe_comb;
  wire    pci_target_par_out_next,  pci_target_par_out_oe_comb;
  wire    pci_target_perr_out_next, pci_target_perr_out_oe_comb;
  wire    pci_target_serr_out_oe_comb;

// Signals to control shared AD bus, Parity, and SERR signals
  wire    Target_Force_AD_to_Data, Target_Exposes_Data_On_IRDY;
  wire    Target_Forces_PERR;
// Signal from Master to say that DMA data should be captured into Response FIFO
  wire    Master_Captures_Data_On_TRDY;

// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  wire   [2:0] master_to_target_status_type;
  wire   [PCI_FIFO_CBE_RANGE:0] master_to_target_status_cbe;
  wire   [PCI_FIFO_DATA_RANGE:0] master_to_target_status_data;
  wire    master_to_target_status_flush;
  wire    master_to_target_status_available, master_to_target_status_unload;

// Signals from the Master to the Target to set bits in the Status Register.
  wire    master_got_parity_error, master_caused_serr;
  wire    master_caused_master_abort, master_got_target_abort;
  wire    master_caused_parity_error;
// Signals used to document Master Behavior
  wire    master_asked_to_retry;
// Signals from the Config Regs to the Master to control it.
  wire    master_enable, master_fast_b2b_en;
  wire    master_perr_enable;
  wire   [7:0] master_latency_value;

// Instantiate the Target Interface, which contains the Config Registers
pci_blue_target pci_blue_target (
// Signals driven to control the external PCI interface
  .pci_ad_in_prev             (pci_ad_in_prev[PCI_BUS_DATA_RANGE:0]),
  .pci_target_ad_out_next     (pci_target_ad_out_next[PCI_BUS_DATA_RANGE:0]),
  .pci_target_ad_en_next      (pci_target_ad_en_next),
  .pci_target_ad_out_oe_comb  (pci_target_ad_out_oe_comb),
  .pci_idsel_in_prev          (pci_idsel_in_prev),
  .pci_cbe_l_in_prev          (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0]),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_par_in_critical        (pci_par_in_critical),
  .pci_target_par_out_next    (pci_target_par_out_next),
  .pci_target_par_out_oe_comb (pci_target_par_out_oe_comb),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_frame_in_critical      (pci_frame_in_critical),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_in_critical       (pci_irdy_in_critical),
  .pci_devsel_out_next        (pci_devsel_out_next),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb),
  .pci_trdy_out_next          (pci_trdy_out_next),
  .pci_stop_out_next          (pci_stop_out_next),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_target_perr_out_next   (pci_target_perr_out_next),
  .pci_target_perr_out_oe_comb (pci_target_perr_out_oe_comb),
  .pci_serr_in_prev           (pci_serr_in_prev),
  .pci_target_serr_out_oe_comb (pci_target_serr_out_oe_comb),
// Signals to control shared AD bus, Parity, and SERR signals
  .Target_Force_AD_to_Data    (Target_Force_AD_to_Data),
  .Target_Exposes_Data_On_IRDY (Target_Exposes_Data_On_IRDY),
  .Target_Forces_PERR         (Target_Forces_PERR),
// Signal from Master to say that DMA data should be captured into Response FIFO
  .Master_Captures_Data_On_TRDY (Master_Captures_Data_On_TRDY),
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  .pci_response_fifo_type     (pci_response_fifo_type[3:0]),
  .pci_response_fifo_cbe      (pci_response_fifo_cbe[PCI_FIFO_CBE_RANGE:0]),
  .pci_response_fifo_data     (pci_response_fifo_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_response_fifo_room_available_meta (pci_response_fifo_room_available_meta),
  .pci_response_fifo_data_load (pci_response_fifo_data_load),
  .pci_response_fifo_error    (pci_response_fifo_error),
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  .pci_delayed_read_fifo_type (pci_delayed_read_fifo_type[2:0]),
  .pci_delayed_read_fifo_data (pci_delayed_read_fifo_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_delayed_read_fifo_data_available_meta (pci_delayed_read_fifo_data_available_meta),
  .pci_delayed_read_fifo_data_unload (pci_delayed_read_fifo_data_unload),
  .pci_delayed_read_fifo_error (pci_delayed_read_fifo_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .master_to_target_status_type   (master_to_target_status_type[2:0]),
  .master_to_target_status_cbe    (master_to_target_status_cbe[PCI_FIFO_CBE_RANGE:0]),
  .master_to_target_status_data   (master_to_target_status_data[PCI_FIFO_DATA_RANGE:0]),
  .master_to_target_status_flush  (master_to_target_status_flush),
  .master_to_target_status_available (master_to_target_status_available),
  .master_to_target_status_unload (master_to_target_status_unload),
  .master_to_target_status_two_words_free (master_to_target_status_two_words_free),
// Signals from the Master to the Target to set bits in the Status Register
  .master_got_parity_error    (master_got_parity_error),
  .master_caused_serr         (master_caused_serr),
  .master_caused_master_abort (master_caused_master_abort),
  .master_got_target_abort    (master_got_target_abort),
  .master_caused_parity_error (master_caused_parity_error),
// Signals used to document Master Behavior
  .master_asked_to_retry      (master_asked_to_retry),
// Signals from the Config Regs to the Master to control it.
  .master_enable              (master_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_perr_enable         (master_perr_enable),
  .master_latency_value       (master_latency_value[7:0]),
// Courtesy indication that PCI Interface Config Register contains an error indication
  .target_config_reg_signals_some_error (target_config_reg_signals_some_error),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (pci_reset_comb)
);

// Master signals to be combined with Target signals on the way to the PCI IO Pads.
  wire   [PCI_BUS_DATA_RANGE:0] pci_master_ad_out_next;
  wire    pci_master_ad_en_next,    pci_master_ad_out_oe_comb;
  wire    pci_master_par_out_next,  pci_master_par_out_oe_comb;
  wire    pci_master_perr_out_next, pci_master_perr_out_oe_comb;

// Signals to control shared AD bus, Parity, and SERR signals
  wire    Master_Force_AD_to_Address_Data_Critical, Master_Exposes_Data_On_TRDY;
  wire    Master_Forces_PERR;
  wire    PERR_Detected_While_Master_Read;
// Signal to control Request pin if on-chip PCI devices share it
  wire    Master_Forced_Off_Bus_By_Target_Abort;

// Instantiate the Master Interface
pci_blue_master pci_blue_master (
// Signals driven to control the external PCI interface
  .pci_req_out_next           (pci_req_out_next),
  .pci_req_out_oe_comb        (pci_req_out_oe_comb),
  .pci_gnt_in_prev            (pci_gnt_in_prev),
  .pci_gnt_in_critical        (pci_gnt_in_critical),
  .pci_master_ad_out_next     (pci_master_ad_out_next[PCI_BUS_DATA_RANGE:0]),
  .pci_master_ad_out_oe_comb  (pci_master_ad_out_oe_comb),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[PCI_BUS_CBE_RANGE:0]),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_frame_in_critical      (pci_frame_in_critical),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_irdy_in_critical       (pci_irdy_in_critical),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_out_next          (pci_irdy_out_next),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_critical       (pci_trdy_in_critical),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_stop_in_critical       (pci_stop_in_critical),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_serr_in_prev           (pci_serr_in_prev),
// Signals to control shared AD bus, Parity, and SERR signals
  .Master_Force_AD_to_Address_Data_Critical (Master_Force_AD_to_Address_Data_Critical),
  .Master_Captures_Data_On_TRDY (Master_Captures_Data_On_TRDY),
  .Master_Exposes_Data_On_TRDY (Master_Exposes_Data_On_TRDY),
  .Master_Forces_PERR         (Master_Forces_PERR),
  .PERR_Detected_While_Master_Read (PERR_Detected_While_Master_Read),
// Signal to control Request pin if on-chip PCI devices share it
  .Master_Forced_Off_Bus_By_Target_Abort (Master_Forced_Off_Bus_By_Target_Abort),
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  .pci_request_fifo_type      (pci_request_fifo_type[2:0]),
  .pci_request_fifo_cbe       (pci_request_fifo_cbe[PCI_FIFO_CBE_RANGE:0]),
  .pci_request_fifo_data      (pci_request_fifo_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_request_fifo_data_available_meta (pci_request_fifo_data_available_meta),
  .pci_request_fifo_two_words_available_meta (pci_request_fifo_two_words_available_meta),
  .pci_request_fifo_data_unload (pci_request_fifo_data_unload),
  .pci_request_fifo_error     (pci_request_fifo_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .master_to_target_status_type   (master_to_target_status_type[2:0]),
  .master_to_target_status_cbe    (master_to_target_status_cbe[PCI_FIFO_CBE_RANGE:0]),
  .master_to_target_status_data   (master_to_target_status_data[PCI_FIFO_DATA_RANGE:0]),
  .master_to_target_status_flush  (master_to_target_status_flush),
  .master_to_target_status_available (master_to_target_status_available),
  .master_to_target_status_unload (master_to_target_status_unload),
// Signals from the Master to the Target to set bits in the Status Register
  .master_got_parity_error    (master_got_parity_error),
  .master_caused_serr         (master_caused_serr),
  .master_caused_master_abort (master_caused_master_abort),
  .master_got_target_abort    (master_got_target_abort),
  .master_caused_parity_error (master_caused_parity_error),
// Signals used to document Master Behavior
  .master_asked_to_retry      (master_asked_to_retry),
// Signals from the Config Regs to the Master to control it.
  .master_enable              (master_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_perr_enable         (master_perr_enable),
  .master_latency_value       (master_latency_value[7:0]),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (pci_reset_comb)
);

// Combine signals which are driven by both the Master and the Target
  wire    Present_Reference_Is_Master;

// Either present the next Master Address or Write Data or the next Target Data
  assign  pci_ad_out_next[PCI_BUS_DATA_RANGE:0] = Present_Reference_Is_Master
                                ? pci_master_ad_out_next[PCI_BUS_DATA_RANGE:0]
                                : pci_target_ad_out_next[PCI_BUS_DATA_RANGE:0];

// As quickly as possible, decide whether to present new data on AD bus or
// to continue sending old data.  The state machines need to know what
// happened too, so they can prepare the data for next time.
// NOTE: IRDY and TRDY are very late.  3 nSec before clock edge!
// NOTE: pci_ad_out_en_next goes to 36 or 72 inputs (+1?).  Very critical.
pci_critical_data_latch_enable pci_critical_data_latch_enable (
  .Master_Expects_TRDY        (Master_Exposes_Data_On_TRDY),
  .pci_trdy_in_critical       (pci_trdy_in_critical),
  .Target_Expects_IRDY        (Target_Exposes_Data_On_IRDY),
  .pci_irdy_in_critical       (pci_irdy_in_critical),
  .New_Data_Unconditional     (   Master_Force_AD_to_Address_Data_Critical
                                | Target_Force_AD_to_Data),
  .pci_ad_out_en_next         (pci_ad_out_en_next)
);

// At a slower pace decide whether to output enable the Data pads.
  assign  pci_ad_out_oe_comb =  pci_master_ad_out_oe_comb
                              | pci_target_ad_out_oe_comb;

// Capture new CBE output data each clock, even if it is not driven for target refs.
  assign  pci_cbe_out_en_next = pci_ad_out_en_next;
// NOTE pci_cbe_out_oe_comb is driven from inside the Master module.

// NOTE: Calculate parity if driving the AD bus.
// NOTE: If target responding to a read, need to include the CURRENT
//       CBE signals, driven by Master.
// NOTE: very timing critical.  3 nSec setup on CBE signals.
// See the PCI Local Bus Spec Revision 2.2 section 3.7.1 for details.
  wire    outgoing_data_parity = (^ pci_ad_out_next[PCI_BUS_DATA_RANGE:0]);
  wire    outgoing_cbe_parity = (^ pci_cbe_l_out_next[PCI_BUS_CBE_RANGE:0]);

  wire    incoming_data_parity = (^ pci_ad_in_prev[PCI_BUS_DATA_RANGE:0]);
  wire    incoming_cbe_parity = (^ pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0]);

  wire    current_cbe_parity = (^ pci_cbe_l_in_critical[PCI_BUS_CBE_RANGE:0]);

// NOTE NOT DONE YET.  Decide what parity to drive
  assign  pci_par_out_next = 1'b0;
  assign  pci_par_out_oe_comb = 1'b0;

//  assign  pci_par_out_oe_comb = pci_master_par_out_oe_comb
//                              | pci_target_par_out_oe_comb;

// PERR must be asserted, then deasserted, then set to high-Z
// SERR is open-collector.  It is asserted, then assumed invalid
// until it is seen deasserted for 2 clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.7.4.2 for details.
  assign  pci_perr_out_next    = pci_master_perr_out_next
                               | pci_target_perr_out_next;
  assign  pci_perr_out_oe_comb = 1'b0  // NOTE: WORKING.  Master can signal PERR on reads
                               | pci_target_perr_out_oe_comb;
  assign  pci_serr_out_oe_comb = pci_target_serr_out_oe_comb;

`ifdef VERBOSE_TEST_DEVICE
// Monitor the activity on the Host Interface of the PCI_Blue_Interface.
monitor_pci_interface_host_port monitor_pci_interface_host_port (
// Wires used by the host controller to request action by the pci interface
  .pci_host_request_data      (pci_host_request_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_host_request_cbe       (pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0]),
  .pci_host_request_type      (pci_host_request_type[2:0]),
  .pci_host_request_room_available_meta  (pci_host_request_room_available_meta),
  .pci_host_request_submit    (pci_host_request_submit),
  .pci_host_request_error     (pci_host_request_error),
// Wires used by the pci interface to request action by the host controller
  .pci_host_response_data     (pci_host_response_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_host_response_cbe      (pci_host_response_cbe[PCI_FIFO_CBE_RANGE:0]),
  .pci_host_response_type     (pci_host_response_type[3:0]),
  .pci_host_response_data_available_meta  (pci_host_response_data_available_meta),
  .pci_host_response_unload   (pci_host_response_unload),
  .pci_host_response_error    (pci_host_response_error),
// Wires used by the host controller to send delayed read data by the pci interface
  .pci_host_delayed_read_data (pci_host_delayed_read_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_host_delayed_read_type (pci_host_delayed_read_type[2:0]),
  .pci_host_delayed_read_room_available_meta  (pci_host_delayed_read_room_available_meta),
  .pci_host_delayed_read_data_submit          (pci_host_delayed_read_data_submit),
  .pci_host_delayed_read_data_error (pci_host_delayed_read_data_error),
  .host_clk                   (host_clk)
);
`endif  // VERBOSE_TEST_DEVICE
endmodule

