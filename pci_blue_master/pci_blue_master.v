//===========================================================================
// $Id: pci_blue_master.v,v 1.6 2001-06-11 08:14:49 bbeaver Exp $
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
// NOTE:  The Master State Machine does one of two things when it sees data
//        in it's Command FIFO:
//        1) Unload the data and use it as either a PCI Address, a PCI
//           Write Data value, or a PCI Read Strobe indication.  In these
//           cases, the data is also sent to the PCI Slave as documentation
//           of PCI Master Activity.
//        2) Unload the data and send it to the PCI Slave for interpretation.
//           This path, which does not need external bus activity, is used
//           when a local configuration register is to be changed, and is
//           also used when a Write Fence is handled.
//
// NOTE:  In all cases, the Master State Machine has to wait to unload data
//        from the Command FIFO until there is room in the Target State Machine
//        Response FIFO to receive the unloaded data.
//
// NOTE:  If there IS room in the PCI Target FIFO, the PCI Master may still
//        have to delay a transfer.  The PCI Target gets to decide which
//        state machine, Master or Target, gets to write the FIFO each clock.
//
// NOTE:  The Master State Machine might also wait even if there is room in the
//        Target State Machine Response FIFO if a Delayed Read is in progress,
//        and the Command FIFO contains either a Write Fence or a Read command.
//
// NOTE:  As events occur on the PCI Bus, the Master State Machine writes
//        Status data to the PCI Target State Machine.
//
// NOTE:  Sometimes, the Master State Machine needs to stick a data item
//        into the Target State Machine Response FIFO even when it is not
//        unloading from the Master State Machine Command FIFO.  This happens
//        when things like disconnects or read data arrives, and also when
//        an error occurs on the bus.
//        If an event occurs which needs to be reported, but the FIFO is
//        not available, the event is remembered and inserted later.
//
// NOTE:  The Master State Machine will unload an entry from the Command FIFO and
//        insert the command into the Response FIFO when these conditions are met:
//        Command FIFO has data in it, and
//        Response FIFO has room to accept data, and
//        No Status indication needs to be sent to Target, and
//        Target not preventing writes for any Target purpose,
//        and one of the following:
//          It's a Write Fence, or
//          It's a Local Configuration Reference, or
//          Master Enabled,and Bus Available, and Address Mode, and
//            It's a Read Address and Target not holding off Reads, or
//            It's a Write Address, or
//          Data Mode, and
//            It's Write Data and local IRDY and external TRDY is asserted, or
//            It's Read Strobes and local IRDY and external TRDY is asserted
//
// NOTE:  This Master State Machine is an implementation of the Master State
//        Machine described in the PCI Local Bus Specification Revision 2.2,
//        Appendix B.  Locking is not supported.
//
// NOTE:  The Master State Machine must make sure that it can accept or
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
  pci_iface_request_two_words_available_meta,
  pci_iface_request_data_unload,
  pci_iface_request_error,
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  pci_master_to_target_request_type,
  pci_master_to_target_request_cbe,
  pci_master_to_target_request_data,
  pci_master_to_target_request_room_available_meta,
  pci_master_to_target_request_data_load,
  pci_master_to_target_request_error,
// Signals from the Master to the Target to let the Delayed Read logic implement
//   the ordering rules.
  pci_master_executing_read,
  pci_master_seeing_write_fence,
// Signals from the Master to the Target to set bits in the Status Register
  master_got_parity_error,
  master_caused_serr,
  master_got_master_abort,
  master_got_target_abort,
  master_caused_parity_error,
  master_request_fifo_error,
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
  input   pci_iface_request_two_words_available_meta;
  output  pci_iface_request_data_unload;
  input   pci_iface_request_error;
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  output [2:0] pci_master_to_target_request_type;
  output [3:0] pci_master_to_target_request_cbe;
  output [31:0] pci_master_to_target_request_data;
  input   pci_master_to_target_request_room_available_meta;
  output  pci_master_to_target_request_data_load;
  input   pci_master_to_target_request_error;
// Signals from the Master to the Target to let the Delayed Read logic implement
//   the ordering rules.
  output  pci_master_executing_read;
  output  pci_master_seeing_write_fence;
// Signals from the Master to the Target to set bits in the Status Register
  output  master_got_parity_error;
  output  master_caused_serr;
  output  master_got_master_abort;
  output  master_got_target_abort;
  output  master_caused_parity_error;
  output  master_request_fifo_error;
  input   master_enable;
  input   master_fast_b2b_en;
  input   master_perr_enable;
  input   master_serr_enable;
  input  [7:0] master_latency_value;
  input   pci_clk;
  input   pci_reset_comb;

  parameter PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS = 1'b0;
  parameter PCI_REQUEST_FIFO_WAITING_FOR_LAST    = 1'b1;

// Check that the Request FIFO is getting entries in the allowed order
//   Address->Data->Data_Last.  Anything else is an error.

  reg     request_fifo_state;  // tracks no_address, address, data, data_last;
  reg     master_request_fifo_error;

  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
    if (pci_reset_comb)
    begin
      master_request_fifo_error <= 1'b0;
      request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
    end
    else
    begin
      if (pci_iface_request_data_available_meta)
      begin
        if (request_fifo_state == PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS)
        begin
          if (  (pci_iface_request_type[2:0] == `PCI_HOST_REQUEST_SPARE)
              | (pci_iface_request_type[2:0] == `PCI_HOST_REQUEST_W_DATA_RW_MASK)
              | (pci_iface_request_type[2:0]
                                == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
              | (pci_iface_request_type[2:0]
                                == `PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR) 
              | (pci_iface_request_type[2:0]
                                == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) )
          begin
            master_request_fifo_error <= 1'b1;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else if (pci_iface_request_type[2:0]
                                == `PCI_HOST_REQUEST_INSERT_WRITE_FENCE)
          begin
            master_request_fifo_error <= pci_iface_request_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else
          begin  // Either type of Address entry is OK
            master_request_fifo_error <= pci_iface_request_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_LAST;
          end
        end
        else  // PCI_FIFO_WAITING_FOR_LAST
        begin
          if (  (pci_iface_request_type[2:0] == `PCI_HOST_REQUEST_SPARE)
              | (pci_iface_request_type[2:0] == `PCI_HOST_REQUEST_ADDRESS_COMMAND)
              | (pci_iface_request_type[2:0]
                                == `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR)
              | (pci_iface_request_type[2:0]
                                == `PCI_HOST_REQUEST_INSERT_WRITE_FENCE) )
          begin
            master_request_fifo_error <= 1'b1;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else if (  (pci_iface_request_type[2:0]
                         == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                   | (pci_iface_request_type[2:0]
                         == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) )
          begin
            master_request_fifo_error <= pci_iface_request_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else
          begin  // Either type of Data without Last
            master_request_fifo_error <= pci_iface_request_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_LAST;
          end
        end
      end
      else
      begin
        master_request_fifo_error <= pci_iface_request_error;
        request_fifo_state <= request_fifo_state;
      end
    end
  end

// The PCI Blue Master gets commands from the pci_request_fifo.
// There are 3 main types of entries:
// 1) Address/Data sequences which cause external PCI activity.
// 2) Config Accesses to the Local PCI Config Registers
// 3) Write Fence tokens.
//
// The PCI Blue Master sends all of the commands over to the Target
//   as soon as they are acted on.  This is so that the reader of the
//   pci_response_fifo can keep track of progress.
// Two of the commands put into the pci_request_fifo are modified by
//   the target before being loaded into the FIFO.
// The Address command can be sent with or without an SERR indication,
//   but the response_fifo combines these into 1 response.
// The Read Config Register command gets echoed into the response_fifo,
//   but only after it has had read data filled in.
//
// The Request FIFO can be unloaded only of all of these three things are true:
// 1) Data available
// 2) Room available in Target FIFO
// 3) PCI interfance on Master Side can accept the data

// NOTE: WORKING manipulate the Request and Response FIFOs here
  assign  pci_iface_request_data_unload = pci_iface_request_data_available_meta;

  wire    Request_FIFO_Empty = 1'b0;
  wire    Request_FIFO_CONTAINS_ADDRESS = 1'b0;
  wire    Request_FIFO_CONTAINS_DATA_MORE = 1'b0;
  wire    Request_FIFO_CONTAINS_DATA_LAST = 1'b0;

/*
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  assign  pci_master_to_target_request_type[2:0] = pci_iface_request_type;
  assign  pci_master_to_target_request_cbe[3:0] = pci_iface_request_cbe;
  assign  pci_master_to_target_request_data[31:0] = pci_iface_request_data;
  assign  pci_master_to_target_request_room_available_meta =
                                     pci_iface_request_data_available_meta;
  assign  pci_master_to_target_request_data_load = pci_iface_request_data_unload;
  assign  pci_master_to_target_request_error = pci_iface_request_error;
// Signals from the Master to the Target to let the Delayed Read logic implement
//   the ordering rules.
  output  pci_master_executing_read;
  output  pci_master_seeing_write_fence;

// The Host sends Requests over the Host Request Bus to initiate PCI activity.
//   The Host Interface is required to send Requests in this order:
//   Address, optionally several Data's, Data_Last.  Sequences of Address-Address,
//   Data-Address, Data_Last-Data, or Data_Last-Data_Last are all illegal.
// First, the Request which indicates that nothing should be put in the FIFO.
`define PCI_HOST_REQUEST_SPARE                           (3'h0)
// Second, the Requests which start a Read or a Write.  Writes can be started
//   before previous Writes complete, but only one Read can be issued at a time.
`define PCI_HOST_REQUEST_ADDRESS_COMMAND                 (3'h1)
`define PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR            (3'h2)
// Third, a Request used during Delayed Reads to mark the Write Command FIFO empty.
// This Request must be issued with Data Bits 16 and 17 both set to 1'b0.
`define PCI_HOST_REQUEST_INSERT_WRITE_FENCE              (3'h3)
// Fourth, a Request used to read and write the local PCI Controller's Config Registers.
// This Request shares it's tags with the WRITE_FENCE Command.  Config References
//   can be identified by noticing that Bits 16 or 17 are non-zero.
// Data Bits [7:0] are the Byte Address of the Config Register being accessed.
// Data Bits [15:8] are the single-byte Write Data used in writing the Config Register.
// Data Bit  [16] indicates that a Config Write should be done.
// Data Bit  [17] indicates that a Config Read should be done.
// This Request must be issued with either Data Bits 16 or 17 set to 1'b1.
// `define PCI_HOST_REQUEST_READ_WRITE_CONFIG_REGISTER      (3'h3)
// Fifth, Requests saying Write Data, Read or Write Byte Masks, and End Burst.
`define PCI_HOST_REQUEST_W_DATA_RW_MASK                  (3'h4)
`define PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST             (3'h5)
`define PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR             (3'h6)
`define PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR        (3'h7)
// These Address and Data Requests always are acknowledged by either a Master Abort,
//   a Target Abort, or a Status Data Last.  Each data item which is delivered over
//   the PCI Bus gets acknowledged by the PCI interface, and each data item not used
//   gets flushed silently after the Master Abort or Target Abort is announced.

// Responses the PCI Controller sends over the Host Response Bus to indicate that
//   progress has been made on transfers initiated over the Request Bus by the Host.
// First, the Response which indicates that nothing should be put in the FIFO.
`define PCI_HOST_RESPONSE_SPARE                          (4'h0)
// Second, a Response repeating the Host Request the PCI Bus is presently servicing.
`define PCI_HOST_RESPONSE_EXECUTED_ADDRESS_COMMAND       (4'h1)
// Third, a Response which gives commentary about what is happening on the PCI bus.
// These bits follow the layout of the PCI Config Register Status Half-word.
// When this Response is received, bits in the data field indicate the following:
// Bit 31: PERR Detected (sent if a Parity Error occurred on the Last Data Phase)
// Bit 30: SERR Detected
// Bit 29: Master Abort received
// Bit 28: Target Abort received
// Bit 27: Caused Target Abort
// Bit 24: Caused PERR
// Bit 18: Discarded a Delayed Read due to timeout
// Bit 17: Target Retry or Disconnect (document that a Master Retry is requested)
// Bit 16: Got Illegal sequence of commands over Host Request Bus.
`define PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT     (4'h2)
// Fourth, a Response saying when the Write Fence has been disposed of.  After this
//   is received, and the Delayed Read done, it is OK to queue more Write Requests.
// This command will be returned in response to a Request issued with Data
//   Bits 16 and 17 both set to 1'b0.
`define PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE          (4'h3)
// Fifth, a Response used to read and write the local PCI Controller's Config Registers.
// This Response shares it's tags with the WRITE_FENCE Command.  Config References
//   can be identified by noticing that Bits 16 or 17 are non-zero.
// Data Bits [7:0] are the Byte Address of the Config Register being accessed.
// Data Bits [15:8] are the single-byte Read Data returned when writing the Config Register.
// Data Bit  [16] indicates that a Config Write has been done.
// Data Bit  [17] indicates that a Config Read has been done.
// This Response will be issued with either Data Bits 16 or 17 set to 1'b1.
// `define PCI_HOST_RESPONSE_READ_WRITE_CONFIG_REGISTER     (4'h3)
// Sixth, Responses indicating that Write Data was delivered, Read Data is available,
//   End Of Burst, and that a Parity Error occurred the previous data cycle.
`define PCI_HOST_RESPONSE_R_DATA_W_SENT                  (4'h4)
`define PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST             (4'h5)
`define PCI_HOST_RESPONSE_R_DATA_W_SENT_PERR             (4'h6)
`define PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR        (4'h7)


// Responses the PCI Controller sends over the Host Response Bus to indicate
//   that an external PCI Master has started a reference.
// The PCI Controller will do a Target Disconnect on each data phase of a Read
//   in which the Byte Strobes command less than a full 4-byte read.
`define PCI_HOST_RESPONSE_EXTERNAL_SPARE                 (4'h8)
// First, the Responses which indicate that an External PCI Master has requested
//   a Read or a Write, depending on the Command.
`define PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE (4'h9)
// Second, the Response which indicates that a Delayed Read must be restarted
//   because a Write by an external PCI Master overlapped the read window.
`define PCI_HOST_RESPONSE_EXT_DELAYED_READ_RESTART       (4'hA)
// Third, the Response which says that all Writes are finished, and the
//   Delayed Read is finally being serviced on the PCI Bus.
`define PCI_HOST_RESPONSE_EXT_READ_UNSUSPENDING          (4'hB)
// Fourth, the Responses saying Write Data, Read or Write Byte Masks, and End Burst.
`define PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK             (4'hC)
`define PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST        (4'hD)
`define PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_PERR        (4'hE)
`define PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR   (4'hF)
*/


// Keep track of the present PCI Address, so the Master can restart references
// if it receives a Target Retry.
// The bottom 2 bits of a PCI Address have special meaning to the
// PCI Master and PCI Target.  See the PCI Local Bus Spec
// Revision 2.2 section 3.2.2.1 and 3.2.2.2 for details.
//
// NOTE: WORKING If a Target Abort is received during a Memory Write
// NOTE: WORKING and invalidate, the reference should be retried as
// NOTE: WORKING as a normal Memory Write.
// See the PCI Local Bus Spec Revision 2.2 section 3.3.3.2.1 for details

  reg    [31:0] Master_Retry_Address;
  reg    [3:0] Master_Retry_Command;
  reg     Grab_Master_Address, Inc_Master_Address;

  always @(posedge pci_clk)
  begin
    if (Grab_Master_Address == 1'b1)
    begin
      Master_Retry_Address[31:0] <= pci_iface_request_data[31:0];
      Master_Retry_Command[3:0] <= pci_iface_request_cbe[3:0];
    end
    else
    begin
      if (Inc_Master_Address == 1'b1)
      begin
        Master_Retry_Address[31:0] <= Master_Retry_Address[31:0]
                                       + 32'h00000004;
      end
      else
      begin
        Master_Retry_Address[31:0] <= Master_Retry_Address[31:0];
      end
      Master_Retry_Command[3:0] <= Master_Retry_Command[3:0];
    end
  end

// Master Aborts are detected when the Master asserts FRAME, and does
// not see DEVSEL in a timely manner.  See the PCI Local Bus Spec
// Revision 2.2 section 3.3.3.1.

  reg    [2:0] Master_Abort_Counter;
  reg     Start_Master_Abort_Counter, Master_Abort_Detected;

  always @(posedge pci_clk)  // NOTE: WHAT ABOUT ASYNC CLEAR?
  begin
    if (Start_Master_Abort_Counter == 1'b1)
    begin
      Master_Abort_Counter[2:0] <= 3'h0;
      Master_Abort_Detected <= 1'b0;
    end
    else
    begin
      Master_Abort_Counter[2:0] <= Master_Abort_Counter[2:0] + 3'h1;
      Master_Abort_Detected <= (Master_Abort_Counter[2:0] == 3'h7);
    end
  end


// Master Data Latency Counter.  Must make progress within 8 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.2 for details.
// NOTE: WORKING EXTREME NIGHTMARE.  A PCI Master must assert Valid
// NOTE: WORKING Write Enables on all clocks, EVEN if IRDY is not
// NOTE: WORKING asserted.  See the PCI Local Bus Spec Revision 2.2
// NOTE: WORKING section 3.2.2 and 3.3.1 for details.
// NOTE: WORKING Might implement this as a Master Disconnect if the
// NOTE: WORKING Master Request FIFO does not have more data
// NOTE: WORKING in the SECOND entry, as needed to deliver the
// NOTE: WORKING NEXT Byte Enable Wires.

  reg    [2:0] Master_Data_Latency_Counter;
  reg     Master_Data_Latency_Disconnect;

  always @(posedge pci_clk)
  begin
    if (pci_reset_comb)
    begin
      Master_Data_Latency_Counter[2:0] <= 3'h0;
      Master_Data_Latency_Disconnect <= 1'b0;
    end
  end

// The Master Latency Counter is needed to force the Master off the bus
// in a timely fashon if it is in the middle of a burst when it's Grant
// is removed.  See the PCI Local Bus Spec Revision 2.2 section 3.5.4

  reg    [7:0] Master_Latency_Timer;
  reg     Clear_Master_Latency_Timer, Master_Latency_Time_Exceeded;

  always @(posedge pci_clk)  // NOTE: WHAT ABOUT ASYNC CLEAR?
  begin
    if (Clear_Master_Latency_Timer == 1'b1)
    begin
      Master_Latency_Timer[7:0] <= 8'h00;
      Master_Latency_Time_Exceeded <= 1'b0;
    end
    else
    begin
      Master_Latency_Timer[7:0] <= Master_Latency_Timer[7:0] + 8'h01;
      Master_Latency_Time_Exceeded <= (Master_Latency_Timer[7:0]  // set
                                          == master_latency_value[7:0])
                                    | Master_Latency_Time_Exceeded;  // hold
    end
  end

// The Master State Machine as described in Appendix B.
// No Lock State Machine is implemented.
// This design supports Medium Decode.  Fast Decode is not supported.
//
// Here is my interpretation of the Master State Machine:
//
// The Master is in one of 3 states when transferring data:
// 1) Waiting,
// 2) Transferring data with more to come,
// 3) Transferring the last Data item.
//
// The Request FIFO can indicate that it
// 1) contains no Data,
// 2) contains Data which is not the last,
// 3) contains the last Data
//
// In addition, the Result FIFO can have room or no room.
// When it has no room, this holds off Master State Machine
// activity the same as if no Write Data or Read Strobes were available.
//
// The Target can say that it wants a Wait State, that it wants
// to transfer Data, that it wants to transfer the Last Data,
// and that it wants to do a Disconnect, Retry, or Target Abort.
// (This last condition will be called Target DRA below.)
//
// The State Sequence is as follows:
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_IDLE,        FIFO Empty           0      0
// Target Don't Care   X      X                0      0  -> MASTER_IDLE
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_IDLE         FIFO Address         0      0
// Target Don't Care   X      X                1      0  -> MASTER_ADDR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_ADDR         FIFO Don't care      1      0
// Target Don't Care   X      X                1      0  -> MASTER_WAIT
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_WAIT,        FIFO Empty           1      0
// Target Wait         0      0                1      0  -> MASTER_WAIT
// Target Data         1      0                1      0  -> MASTER_WAIT
// Target Last Data    1      1                1      0  -> MASTER_WAIT
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_WAIT,        FIFO non-Last Data   1      0
// Target Wait         0      0                1      1  -> MASTER_DATA_MORE
// Target Data         1      0                1      1  -> MASTER_DATA_MORE
// Target Last Data    1      1                0      1  -> MASTER_DATA_LAST
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_WAIT,        FIFO Last Data       1      0
// Target Wait         0      0                0      1  -> MASTER_DATA_LAST
// Target Data         1      0                0      1  -> MASTER_DATA_LAST
// Target Last Data    1      1                0      1  -> MASTER_DATA_LAST
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_DATA_MORE,   FIFO Empty           1      1
// Target Wait         0      0                1      1  -> MASTER_DATA_MORE
// Target Data         1      0                1      0  -> MASTER_WAIT
// Target Last Data    1      1                0      1  -> MASTER_DATA_LAST
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_DATA_MORE,   FIFO non-Last Data   1      1
// Target Wait         0      0                1      1  -> MASTER_DATA_MORE
// Target Data         1      0                1      1  -> MASTER_DATA_MORE
// Target Last Data    1      1                0      1  -> MASTER_DATA_LAST
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_DATA_MORE,   FIFO Last Data       1      1
// Target Wait         0      0                1      1  -> MASTER_DATA_MORE
// Target Data         1      0                0      1  -> MASTER_DATA_LAST
// Target Last Data    1      1                0      1  -> MASTER_DATA_LAST
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_DATA_LAST,   FIFO Empty           0      1 (or if no Fast Back-to-Back)
// Target Wait         0      0                0      1  -> MASTER_DATA_LAST
// Target Data         1      0                0      0  -> MASTER_IDLE
// Target Last Data    1      1                0      0  -> MASTER_IDLE
// Target DRA          0      1                0      0  -> MASTER_IDLE
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_DATA_LAST,   FIFO Address         0      1 (and if Fast Back-to-Back)
// Target Don't Care   X      X                1      0  -> MASTER_ADDR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_S_TAR,       FIFO Empty           0      1 (or if no Fast Back-to-Back)
// Target Don't Care   X      X                0      0  -> MASTER_IDLE
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_S_TAR,       FIFO Address         0      1 (and if Fast Back-to-Back)
// Target Don't Care   X      X                1      0  -> MASTER_ADDR
//
// NOTE: that in all cases, the FRAME and IRDY signals are calculated
//   based on the TRDY and STOP signals, which are very late and very
//   timing critical.
// The functions will be implemented as a 4-1 MUX using TRDY and STOP
//   as the selection variables.
// The inputs to the FRAME and IRDY MUX's will be decided based on the state
//   the Master is in, and also on the contents of the Request FIFO.
// NOTE: that for both FRAME and IRDY, there are 5 possible functions of
//   TRDY and STOP.  Both output bits might be all 0's, all 1's, and
//   each has 3 functions which are not all 0's nor all 1's.
// NOTE: These extremely timing critical functions will each be implemented
//   as a single CLB in a Xilinx chip, with a 3-bit Function Selection
//   paramater.  The 3 bits plus TRDY plus STOP use up a 5-input LUT.
//
// The functions are as follows:
//    Function Sel [2:0]  TRDY  STOP  ->  FRAME  IRDY
//                  0XX    X     X          0     0
//
//                  100    X     X          1     1
//
// Target Wait      101    0     0          1     0
// Target DRA       101    0     1          0     1
// Target Data      101    1     0          1     0
// Target Last Data 101    1     1          1     0
//
// Target Wait      110    0     0          1     1
// Target DRA       110    0     1          0     1
// Target Data      110    1     0          1     0
// Target Last Data 110    1     1          0     1
//
// Target Wait      111    0     0          1     1
// Target DRA       111    0     1          0     0
// Target Data      111    1     0          0     0
// Target Last Data 111    1     1          0     0
//
// For each state, use the function:       F(Frame) F(IRDY)
//    MASTER_IDLE,        FIFO Empty          000     000 (no FRAME, IRDY)
//    MASTER_IDLE         FIFO Address        100     000 (Always FRAME)
//    MASTER_ADDR         FIFO Don't care     100     000 (Always FRAME)
//    MASTER_WAIT,        FIFO Empty          101     101 (FRAME unless DRA)
//    MASTER_WAIT,        FIFO non-Last Data  110     100
//    MASTER_WAIT,        FIFO Last Data      000     100
//    MASTER_DATA_MORE,   FIFO Empty          110     110
//    MASTER_DATA_MORE,   FIFO non-Last Data  110     100
//    MASTER_DATA_MORE,   FIFO Last Data      111     100
//    MASTER_DATA_LAST,   FIFO Empty          000     111 (or if no Fast Back-to-Back)
//    MASTER_DATA_LAST,   FIFO Address        100     000 (and if Fast Back-to-Back)
//    MASTER_S_TAR,       FIFO Empty          000     000 (or if no Fast Back-to-Back)
//    MASTER_S_TAR,       FIFO Address        100     000 (and if Fast Back-to-Back)
//    MASTER_DR_BUS,      FIFO Empty          000     000 (no FRAME, IRDY)
//    MASTER_DR_BUS,      FIFO_Address        100     000 (Always FRAME)

  parameter PCI_MASTER_IDLE      = 8'b00000001;  // Master in IDLE state
  parameter PCI_MASTER_ADDR      = 8'b00000010;  // Master Drives Address
  parameter PCI_MASTER_ADDR2     = 8'b00000100;  // Master Drives Address in 64-bit address mode
  parameter PCI_MASTER_WAIT      = 8'b00001000;  // Waiting for Master Data
  parameter PCI_MASTER_DATA_MORE = 8'b00010000;  // Master Transfers Data
  parameter PCI_MASTER_DATA_LAST = 8'b00100000;  // Master Transfers Last Data
  parameter PCI_MASTER_S_TAR     = 8'b01000000;  // Stop makes Turn Around
  parameter PCI_MASTER_DR_BUS    = 8'b10000000;  // Address Step or Bus Park
  reg [7:0] PCI_Master_State;

// These correspond to       {trdy, stop}
  parameter TARGET_IDLE      = 2'b00;
  parameter TARGET_TAR       = 2'b01;
  parameter TARGET_DATA_MORE = 2'b10;
  parameter TARGET_DATA_LAST = 2'b11;

// Experience with the PCI Master Interface teaches that the signals
//   FRAME and IRDY are extremely time critical.  These signals cannot be
//   latched in the IO pads.  The signals must be acted upon by the
//   Target State Machine as combinational inputs.
//
// The combinational logic is below.  This feeds into an Output Flop
//   which is right at the IO pad.  The State Machine uses the Frame,
//   IRDY, DEVSEL, TRDY, and STOP signals which are latched in the
//   input pads.  Therefore, all the fast stuff is in the gates below
//   this case statement.

// NOTE: WORKING implement Address Stepping on Config Refs somehow

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb)
    begin
      PCI_Master_State <= PCI_MASTER_IDLE;
    end
    else
    begin
      case (PCI_Master_State[7:0])
      PCI_MASTER_IDLE:
        begin
// NOTE WORKING need to hop to MASTER_DR_BUS from IDLE somehow?
          if (Request_FIFO_Empty)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;
          end
          else if (Request_FIFO_CONTAINS_ADDRESS)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master IDLE Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_ADDR:
        begin  // when 64-bit Address added, -> PCI_MASTER_ADDR2
          PCI_Master_State[7:0] <= PCI_MASTER_WAIT;
        end
      PCI_MASTER_ADDR2:
        begin  // Not implemented yet. Will be identical to Wait
          PCI_Master_State[7:0] <= PCI_MASTER_WAIT;
        end
      PCI_MASTER_WAIT:
        begin
          if (Request_FIFO_Empty)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_WAIT;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_WAIT;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_WAIT;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_MORE)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_DATA_MORE;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_LAST)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else  // Request_FIFO_CONTAINS_ADDRESS.  Bug
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master WAIT Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_DATA_MORE:
        begin
          if (Request_FIFO_Empty)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_WAIT;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Data More TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_MORE)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_DATA_MORE;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Data More TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_LAST)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Data More TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else  // Request_FIFO_CONTAINS_ADDRESS.  Bug
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master Data More Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_DATA_LAST:
        begin
          if (Request_FIFO_Empty)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;
            TARGET_TAR:       PCI_Master_State[7:0] <= PCI_MASTER_IDLE;
            TARGET_DATA_MORE: PCI_Master_State[7:0] <= PCI_MASTER_IDLE;
            TARGET_DATA_LAST: PCI_Master_State[7:0] <= PCI_MASTER_IDLE;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[7:0] <= PCI_MASTER_WAIT;  // error
                $display ("PCI Master Data Last TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_ADDRESS)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_DATA_LAST;  // error
// synopsys translate_off
            $display ("PCI Master Data Last Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_S_TAR:
        begin
          if (Request_FIFO_Empty)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;
          end
          else if (Request_FIFO_CONTAINS_ADDRESS)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master S_TAR Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_DR_BUS:
        begin
          if (Request_FIFO_Empty)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;
          end
          else if (Request_FIFO_CONTAINS_ADDRESS)
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master DR Bus Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
          end
        end
      default:
        begin
          PCI_Master_State[7:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
          $display ("PCI Master State Machine Unknown %x at time %t",
                           PCI_Master_State[7:0], $time);
// synopsys translate_on
        end
      endcase
    end
  end

// As far as I can tell, this is the story.
//
// Default is no FRAME, no IRDY.  This is the PCI_MASTER_IDLE State.
//
// At the beginning of a transfer, the Master asserts FRAME and
//   not IRDY for 1 clock, independent of all other signals, to
//   indicate Address Valid.  This is the PCI_MASTER_ADDR state.
//
// The Master then might choose to insert Wait States.  A Wait
//   State is when FRAME and not IRDY are asserted.  The Wait
//   State can be ended when the Master has data to transfer, or the
//   Wait State might also end when a Target Disconnect with no
//   data or a Target Abort happens.  The Wait State will not
//   end if a Target Disconnect With Data happens, unless the
//   Master is also ready to transfer data.  This is the
//   PCI_MASTER_DATA_OR_WAIT state.
//
// At the end of the address phase or a wait state, the Master
//   will either assert FRAME with IRDY to indicate that data is
//   ready and that more data will be available, or it will assert
//   no FRAME and IRDY to indicate that the last data is available.
//   The Data phase will end when the Target indicates that a
//   Target Disconnect with no data or a Target Abort has occurred,
//   or that the Target has transfered data.  The Target can also
//   indicate that this should be a target disconnect with data.
//   This is also the PCI_MASTER_DATA_OR_WAIT state.
//
// In some situations, like when a Master Abort happens, or when
//   certain Target Aborts happen, the Master will have to transition
//   om asserting FRAME and not IRDY to no FRAME and IRDY, to let
//   the target end the transfer state sequence correctly.
//   This is the PCI_MASTER_S_TAR state

// As quickly as possible, decide whether to present new Master Control Info
//   on Master Control bus, or to continue sending old data.  The state machine
//   needs to know what happened too, so it can prepare the Control info for
//   next time.
// NOTE: IRDY and TRDY are very late.  3 nSec before clock edge!
// NOTE: The FRAME_Next and IRDY_Next signals are latched in the
//       outputs pad in the IO pad module.

  wire   [2:0] PCI_Next_FRAME_Code = 3'h0;  // NOTE: WORKING
  wire   [2:0] PCI_Next_IRDY_Code = 3'h0;  // NOTE: WORKING

// The PCI Bus gets either data directly from the FIFO or it gets the stored
// address, which has been incrementing until the previous Target Retry was received.
  reg     Select_Stored_Master_Address;
  assign  pci_master_ad_out_next[31:0] = Select_Stored_Master_Address
                                       ? Master_Retry_Address[31:0]
                                       : pci_iface_request_data[31:0];
  assign  pci_cbe_l_out_next[3:0] =      Select_Stored_Master_Address
                                       ? Master_Retry_Command[3:0]
                                       : pci_iface_request_cbe[3:0];

  assign  pci_master_ad_out_oe_comb = 1'b0;
  assign  pci_cbe_out_oe_comb = 1'b0;
  assign  pci_frame_out_oe_comb = 1'b0;
  assign  pci_irdy_out_oe_comb = 1'b0;

  assign  pci_master_par_out_oe_comb = 1'b0;  // NOTE WORKING move to top-level?
  assign  pci_master_perr_out_oe_comb = 1'b0;
  assign  pci_master_serr_out_oe_comb = 1'b0;

  assign  pci_master_to_target_request_data_load = 1'b0;  // NOTE: WORKING

pci_critical_next_frame pci_critical_next_frame (
  .PCI_Next_FRAME_Code        (PCI_Next_FRAME_Code[2:0]),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_stop_in_comb           (pci_stop_in_comb),
  .pci_frame_out_next         (pci_frame_out_next)
);

pci_critical_next_irdy pci_critical_next_irdy (
  .PCI_Next_IRDY_Code         (PCI_Next_IRDY_Code[2:0]),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_stop_in_comb           (pci_stop_in_comb),
  .pci_irdy_out_next          (pci_irdy_out_next)
);
endmodule

