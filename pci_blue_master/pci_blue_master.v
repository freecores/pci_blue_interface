//===========================================================================
// $Id: pci_blue_master.v,v 1.11 2001-06-21 10:06:01 bbeaver Exp $
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
// NOTE:  The Master State Machine will unload an entry from the Command FIFO and
//        insert the command into the Response FIFO when these conditions are met:
//        Command FIFO has data in it, and
//        Response FIFO has room to accept data,
//        and one of the following:
//          It's a Write Fence, or
//          It's a Local Configuration Reference, or
//          Master Enabled, and Bus Available, and Address Mode, and
//            It's a Read Address and Target not holding off Reads, or
//            It's a Write Address, or
//          Data Mode, and
//            It's Write Data and local IRDY and external TRDY is asserted, or
//            It's Read Strobes and local IRDY and external TRDY is asserted
//
// NOTE:  The writer of the FIFO must notice whether it is doing an IO reference
//        with the bottom 2 bits of the address not both 0.  If an IO reference
//        is done with at least 1 bit non-zero, the transfer must be a single
//        word transfer.  See the PCI Local Bus Specification Revision 2.2,
//        section 3.2.2.1
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
// Signals to control shared AD bus, Parity, and SERR signals
  Master_Force_Address_Data,
  Master_Expects_TRDY,
  Master_Requests_PERR,
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  pci_request_fifo_type,
  pci_request_fifo_cbe,
  pci_request_fifo_data,
  pci_request_fifo_data_available_meta,
  pci_request_fifo_two_words_available_meta,
  pci_request_fifo_data_unload,
  pci_request_fifo_error,
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  master_to_target_status_type,
  master_to_target_status_cbe,
  master_to_target_status_data,
  master_to_target_status_available,
  master_to_target_status_unload,
// Signals from the Master to the Target to set bits in the Status Register
  master_got_parity_error,
  master_caused_serr,
  master_caused_master_abort,
  master_got_target_abort,
  master_caused_parity_error,
// Signals used to document Master Behavior
  master_asked_to_retry,
// Signals from the Config Regs to the Master to control it.
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
  output [3:0] pci_cbe_l_out_next;
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
// Signals to control shared AD bus, Parity, and SERR signals
  output  Master_Force_Address_Data;
  output  Master_Expects_TRDY;
  output  Master_Requests_PERR;
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  input  [2:0] pci_request_fifo_type;
  input  [3:0] pci_request_fifo_cbe;
  input  [31:0] pci_request_fifo_data;
  input   pci_request_fifo_data_available_meta;
  input   pci_request_fifo_two_words_available_meta;
  output  pci_request_fifo_data_unload;
  input   pci_request_fifo_error;  // NOTE MAKE SURE THIS IS NOTED SOMEWHERE
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  output [2:0] master_to_target_status_type;
  output [3:0] master_to_target_status_cbe;
  output [31:0] master_to_target_status_data;
  output  master_to_target_status_available;
  input   master_to_target_status_unload;
// Signals from the Master to the Target to set bits in the Status Register
  output  master_got_parity_error;
  output  master_caused_serr;
  output  master_caused_master_abort;
  output  master_got_target_abort;
  output  master_caused_parity_error;
// Signals used to document Master Behavior
  output  master_asked_to_retry;
// Signals from the Config Regs to the Master to control it.
  input   master_enable;
  input   master_fast_b2b_en;
  input   master_perr_enable;
  input   master_serr_enable;
  input  [7:0] master_latency_value;
  input   pci_clk;
  input   pci_reset_comb;

// Decide on when to unload an entry from the Request FIFO (usually into Status
//   FIFO, and sometimes into the Address Hold register or the PCI Output Pads)
// NOTE: TRDY is VERY LATE.  Try to make the logic FAST through TRDY
  wire    Master_Unloading_Request_Now, Master_Asserting_IRDY_Now;  // forward reference

  assign  pci_request_fifo_data_unload = Master_Unloading_Request_Now  // unconditional
               | (Master_Asserting_IRDY_Now & pci_trdy_in_comb);  // be fast on TRDY

// synopsys translate_off
// Check that the Request FIFO is getting entries in the allowed order
//   Address->Data->Data_Last.  Anything else is an error.
//   NOTE: ONLY CHECKED IN SIMULATION.  In the real circuit, the FIFO
//         FILLER is responsible for only writing valid stuff into the FIFO.
  parameter PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS = 1'b0;
  parameter PCI_REQUEST_FIFO_WAITING_FOR_LAST    = 1'b1;
  reg     request_fifo_state;  // tracks no_address, address, data, data_last;
  reg     master_request_fifo_error;  // Notices FIFO error, or FIFO Contents out of sequence

  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
    if (pci_reset_comb == 1'b1)
    begin
      master_request_fifo_error <= 1'b0;
      request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
    end
    else
    begin
      if (pci_request_fifo_data_unload == 1'b1)  // & pci_request_fifo_data_available_meta
      begin
        if (request_fifo_state == PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS)
        begin
          if (  (pci_request_fifo_type[2:0] == `PCI_HOST_REQUEST_SPARE)
              | (pci_request_fifo_type[2:0] == `PCI_HOST_REQUEST_W_DATA_RW_MASK)
              | (pci_request_fifo_type[2:0]
                                == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
              | (pci_request_fifo_type[2:0]
                                == `PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR) 
              | (pci_request_fifo_type[2:0]
                                == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) )
          begin
            master_request_fifo_error <= 1'b1;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else if (pci_request_fifo_type[2:0]
                                == `PCI_HOST_REQUEST_INSERT_WRITE_FENCE)
          begin
            master_request_fifo_error <= pci_request_fifo_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else
          begin  // Either type of Address entry is OK
            master_request_fifo_error <= pci_request_fifo_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_LAST;
          end
        end
        else  // PCI_FIFO_WAITING_FOR_LAST
        begin
          if (  (pci_request_fifo_type[2:0] == `PCI_HOST_REQUEST_SPARE)
              | (pci_request_fifo_type[2:0] == `PCI_HOST_REQUEST_ADDRESS_COMMAND)
              | (pci_request_fifo_type[2:0]
                                == `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR)
              | (pci_request_fifo_type[2:0]
                                == `PCI_HOST_REQUEST_INSERT_WRITE_FENCE) )
          begin
            master_request_fifo_error <= 1'b1;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else if (  (pci_request_fifo_type[2:0]
                         == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                   | (pci_request_fifo_type[2:0]
                         == `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) )
          begin
            master_request_fifo_error <= pci_request_fifo_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else
          begin  // Either type of Data without Last
            master_request_fifo_error <= pci_request_fifo_error;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_LAST;
          end
        end
      end
      else  // either FIFO empty or not unloaded this time
      begin
        master_request_fifo_error <= pci_request_fifo_error;
        request_fifo_state <= request_fifo_state;
      end
    end
  end

  always @(posedge pci_clk)
  begin
    if ((pci_reset_comb == 1'b0) & (master_request_fifo_error == 1'b1))
    begin
      $display ("PCI Master Request Fifo Unload Error at time %t", $time);
    end
  end
// synopsys translate_on

// Buffer Signals from the Request FIFO to the Target to insert
// the Status Info into the Response FIFO.
// The Master will only make progress when this Buffer between
// Master and Target is empty.
// NOTE: These buffers almost certainly don't need to be here.  However, by
//       including buffers, the Master becomes very independent of the Target.
  reg    [2:0] master_to_target_status_type_reg;
  reg    [3:0] master_to_target_status_cbe_reg;
  reg    [31:0] master_to_target_status_data_reg;
  wire    Master_Flushing_Request_FIFO;  // forward declaration
  wire    master_to_target_status_room_available;  // forward declaration

  always @(posedge pci_clk)
  begin
    if (master_to_target_status_room_available == 1'b1)  // capture whenever room available
    begin
      master_to_target_status_type_reg[2:0]  <=
                        (pci_request_fifo_type[2:0] ==  // drop SERR indication
                                         `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR)
                     ?  `PCI_HOST_REQUEST_ADDRESS_COMMAND  // Fold ADDR_SERR to ADDR
                     : ((Master_Flushing_Request_FIFO)  // Flushing; mark Data as Data_PERR
                     ?  `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR  // _SERR indicates Flush
                     :   pci_request_fifo_type[2:0]);    // pass through unchanged
      master_to_target_status_cbe_reg[3:0]   <= pci_request_fifo_cbe[3:0];
      master_to_target_status_data_reg[31:0] <= pci_request_fifo_data[31:0];
    end
    else
    begin
      master_to_target_status_type_reg[2:0]  <=
                                      master_to_target_status_type_reg[2:0];
      master_to_target_status_cbe_reg[3:0]   <=
                                      master_to_target_status_cbe_reg[3:0];
      master_to_target_status_data_reg[31:0] <=
                                      master_to_target_status_data_reg[31:0];
    end
  end

// Send data to Target from Latches which make the logic easier to understand
  assign  master_to_target_status_type[2:0] = master_to_target_status_type_reg[2:0];
  assign  master_to_target_status_cbe[3:0] = master_to_target_status_cbe_reg[3:0];
  assign  master_to_target_status_data[31:0] = master_to_target_status_data_reg[31:0];

// Empty/Full bit to control the use of the Master-to-Target buffer
// NOTE: TRDY is VERY LATE.  This must be implemented to let TRDY operate quickly
  wire    mark_master_to_target_status_full_if_trdy;  // forward declaration
  wire    mark_master_to_target_status_full_if_not_trdy;  // forward declaration
  reg     master_to_target_status_full;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      master_to_target_status_full <= 1'b0;
    end
    else
    begin
      if (pci_trdy_in_comb == 1'b1)  // pci_trdy_in_comb is VERY LATE
      begin
        master_to_target_status_full <= mark_master_to_target_status_full_if_trdy;
      end
      else
      begin
        master_to_target_status_full <= mark_master_to_target_status_full_if_not_trdy;
      end
    end
  end

// Send Register Empty/Full indication to Target
  assign  master_to_target_status_available = master_to_target_status_full;

// Decide whether to capture new status, based on Target activity.
  assign  master_to_target_status_room_available = ~master_to_target_status_full
                                                 |  master_to_target_status_unload;

// The PCI Blue Master gets commands from the pci_request_fifo.
// There are 3 main types of entries:
// 1) Address/Data sequences which cause external PCI activity.
// 2) Config Accesses to the Local PCI Config Registers.
// 3) Write Fence tokens.  These act just like Register Reverences.
//
// The Host Interface is required to send Requests in this order:
//   Address, optionally several Data's, Data_Last.  Sequences of Address-Address,
//   Data-Address, Data_Last-Data, or Data_Last-Data_Last are all illegal.
// The FIFO contents are:
// PCI_HOST_REQUEST_SPARE                           (3'h0)
// PCI_HOST_REQUEST_ADDRESS_COMMAND                 (3'h1)
// PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR            (3'h2)
// This Request must be issued with both Data Bits 16 and 17 set to 1'b0.
// PCI_HOST_REQUEST_INSERT_WRITE_FENCE              (3'h3)
// This Request must be issued with either Data Bits 16 or 17 set to 1'b1.
// `define PCI_HOST_REQUEST_READ_WRITE_CONFIG_REGISTER   (3'h3)
// PCI_HOST_REQUEST_W_DATA_RW_MASK                  (3'h4)
// PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST             (3'h5)
// PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR             (3'h6)
// PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR        (3'h7)
// These Address and Data Requests always are acknowledged by either a Master Abort,
//   a Target Abort, or a Status Data Last.  Each data item which is delivered over
//   the PCI Bus gets acknowledged by the PCI interface, and each data item not used
//   gets flushed silently after the Master Abort or Target Abort is announced.
//
// The PCI Blue Master sends all of the commands over to the Target
//   as Status as soon as they are acted on.  This is so that the reader
//   of the pci_response_fifo can keep track of the Master's progress.
// Some of the commands put into the status are modified by the Master
//   before being loaded into the FIFO.
// The Address command can be sent with or without an SERR indication,
//   but the response_fifo combines these into 1 Address response.
// When data is being flushed, it is passed as Status indications to the Target
//   State Machine using the value PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR.
//
// NOTE: EXTREME NIGHTMARE.  A PCI Master must assert Valid Write Enables
//   on all clocks, EVEN if IRDY is not asserted.  See the PCI Local
//   Bus Spec Revision 2.2 section 3.2.2 and 3.3.1 for details.
//   This means that the Master CAN'T assert an Address until the NEXT
//   Data Strobes are available, and can't assert IRDY on data unless
//   the Data is either the LAST data, or the NEXT data is available.
//   In the case of a Timeout, the Master has to convert a Data into
//   a Data_Last, so that it doesn't need to come up with the NEXT
//   Data Byte Enables.
//   The reference can only be retried once the late data becomes available.
//
// The Request FIFO can be unloaded only of all of these three things are true:
// 1) Room available in Status FIFO to accept data
// 2) Address + next, or Data + next, or Data_Last, or Reg_Ref, or Fence, in FIFO
// 3) If Data Phase, External Device on PCI bus can transfer data,
//    otherwise send data immediately into Status FIFO.
// NOTE: In the case of Master Abort, this FIFO needs to be flushed till Data_Last
// NOTE: Other logic will mix in the various timeouts which can happen.
  wire    Master_Retry_Address_Available;  // forward reference.  Only when waiting for bus
  wire    Request_FIFO_CONTAINS_ADDRESS =
                  master_to_target_status_room_available  // target ready for status
               &  pci_request_fifo_data_available_meta  // at least 1 word
               & (    Master_Retry_Address_Available  // retry address phase
                   | (   (   (pci_request_fifo_type[2:0] ==  // new address
                              `PCI_HOST_REQUEST_ADDRESS_COMMAND)
                           | (pci_request_fifo_type[2:0] ==  // new address
                              `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR))
                       &  pci_request_fifo_two_words_available_meta));  // 2 words
  wire    Request_FIFO_CONTAINS_DATA_MORE =
                  master_to_target_status_room_available  // target ready for status
               &  pci_request_fifo_data_available_meta  // at least 1 word
               & ~Master_Retry_Address_Available  // not retry address phase
               & (   (pci_request_fifo_type[2:0] ==  // new data
                      `PCI_HOST_REQUEST_W_DATA_RW_MASK)
                   | (pci_request_fifo_type[2:0] ==  // new data
                      `PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR))
               &  pci_request_fifo_two_words_available_meta; // 2 words
  wire    Request_FIFO_CONTAINS_DATA_LAST =
                  master_to_target_status_room_available  // target ready for status
               &  pci_request_fifo_data_available_meta  // at least 1 word
               & ~Master_Retry_Address_Available  // not retry address phase
               & (   (pci_request_fifo_type[2:0] ==  // new data
                      `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                   | (pci_request_fifo_type[2:0] ==  // new data
                      `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR));
  wire    Request_FIFO_CONTAINS_HOUSEKEEPING_DATA =
                  master_to_target_status_room_available  // target ready for status
               &  pci_request_fifo_data_available_meta  // only 1 word
               & (   (pci_request_fifo_type[2:0] ==
                      `PCI_HOST_REQUEST_INSERT_WRITE_FENCE)  // also Reg Refs
                   | (pci_request_fifo_type[2:0] ==
                      `PCI_HOST_REQUEST_SPARE));
  wire    Request_FIFO_Empty = ~(   Request_FIFO_CONTAINS_ADDRESS
                                  | Request_FIFO_CONTAINS_DATA_MORE
                                  | Request_FIFO_CONTAINS_DATA_LAST
                                  | Request_FIFO_CONTAINS_HOUSEKEEPING_DATA);

//  Calculate whether the Status FIFO should have data marked as valid based
//    on present Master state, the state of all FIFOs, and the combinational
//    input TRDY.
// NOTE: TRDY is VERY LATE.  The TRDY selection is done above to ensure the
//    best speed.  Calculate BOTH cases here, where speed isn't critical.
//       Add the same term to both cases if it is a don't care in TRDY.
  wire    Master_Writing_Status_Now;  // forward declarations
  assign  mark_master_to_target_status_full_if_trdy =
                 Master_Writing_Status_Now  // Address going out on bus, or Housekeeping
               | (    master_to_target_status_full  // hold term if no data transfer
                   & ~master_to_target_status_unload)  // and no Status FIFO unload
               | Master_Asserting_IRDY_Now;  // If both IRDY and TRDY, full = 1
  assign  mark_master_to_target_status_full_if_not_trdy =
                 Master_Writing_Status_Now  // Address going out on bus, or Housekeeping
               | (    master_to_target_status_full  // hold term if no data transfer
                   & ~master_to_target_status_unload);  // and no Status FIFO unload

// Keep track of the present PCI Address, so the Master can restart references
// if it receives a Target Retry.
// The bottom 2 bits of a PCI Address have special meaning to the
// PCI Master and PCI Target.  See the PCI Local Bus Spec
// Revision 2.2 section 3.2.2.1 and 3.2.2.2 for details.
// The PCI Master will never do a Burst when the command is an IO command.
  reg    [31:2] Master_Retry_Address;
  reg    [3:0] Master_Retry_Command;
  wire    Master_Grab_Address, Master_Inc_Address, Master_Got_Retry;

  always @(posedge pci_clk)
  begin
    if (Master_Grab_Address == 1'b1)
    begin
      Master_Retry_Address[31:2] <= pci_request_fifo_data[31:2];
      Master_Retry_Command[3:0] <= pci_request_fifo_cbe[3:0];
    end
    else
    begin
      if (Master_Inc_Address == 1'b1)
      begin
        Master_Retry_Address[31:2] <= Master_Retry_Address[31:2]
                                       + 30'h00000001;
      end
      else
      begin
        Master_Retry_Address[31:2] <= Master_Retry_Address[31:2];
      end
// NOTE: If a Target Abort is received during a Memory Write and Invalidate,
// NOTE:   the reference should be retried as a normal Memory Write.
// See the PCI Local Bus Spec Revision 2.2 section 3.3.3.2.1 for details
      if ((Master_Got_Retry == 1'b1)
           & (Master_Retry_Command[3:0] ==
                 `PCI_COMMAND_MEMORY_WRITE_INVALIDATE))
      begin
        Master_Retry_Command[3:0] <= `PCI_COMMAND_MEMORY_WRITE;
      end
      else
      begin
        Master_Retry_Command[3:0] <= Master_Retry_Command[3:0];
      end
    end
  end

// Master Aborts are detected when the Master asserts FRAME, and does
// not see DEVSEL in a timely manner.  See the PCI Local Bus Spec
// Revision 2.2 section 3.3.3.1.
  reg    [2:0] Master_Abort_Counter;
  reg     Master_Got_Devsel, Master_Abort_Detected;
  wire    Master_Start_Master_Abort_Counter;

  always @(posedge pci_clk)  // NOTE: WHAT ABOUT ASYNC CLEAR?
  begin
    if (Master_Start_Master_Abort_Counter == 1'b1)
    begin
      Master_Abort_Counter[2:0] <= 3'h0;
      Master_Got_Devsel <= 1'b0;
      Master_Abort_Detected <= 1'b0;
    end
    else
    begin
      Master_Abort_Counter[2:0] <= Master_Abort_Counter[2:0] + 3'h1;
      Master_Got_Devsel <= pci_devsel_in_prev | Master_Got_Devsel;
      Master_Abort_Detected <= ~Master_Got_Devsel
                             & (Master_Abort_Counter[2:0] == 3'h7);
    end
  end

// Master Data Latency Counter.  Must make progress within 8 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.2 for details.
  reg    [2:0] Master_Data_Latency_Counter;
  reg     Master_Data_Latency_Disconnect;

  always @(posedge pci_clk)
  begin
    if (   Request_FIFO_CONTAINS_ADDRESS  // All these indicate that Data Available
         | Request_FIFO_CONTAINS_DATA_MORE
         | Request_FIFO_CONTAINS_DATA_LAST)
    begin
      Master_Data_Latency_Counter[2:0] <= 3'h0;
      Master_Data_Latency_Disconnect <= 1'b0;
    end
    else
    begin
      Master_Data_Latency_Counter[2:0] <= Master_Data_Latency_Counter[2:0] + 3'h1;
      Master_Data_Latency_Disconnect <= (Master_Data_Latency_Counter[2:0] == 3'h7);
    end
  end

// The Master Latency Counter is needed to force the Master off the bus
// in a timely fashion if it is in the middle of a burst when it's Grant
// is removed.  See the PCI Local Bus Spec Revision 2.2 section 3.5.4
  reg    [7:0] Master_Bus_Latency_Timer;
  wire    Master_Clear_Bus_Latency_Timer;
  reg     Master_Bus_Latency_Time_Exceeded;

  always @(posedge pci_clk)  // NOTE: WHAT ABOUT ASYNC CLEAR?
  begin
    if (Master_Clear_Bus_Latency_Timer == 1'b1)
    begin
      Master_Bus_Latency_Timer[7:0] <= 8'h00;
      Master_Bus_Latency_Time_Exceeded <= 1'b0;
    end
    else
    begin
      Master_Bus_Latency_Timer[7:0] <= Master_Bus_Latency_Timer[7:0] + 8'h01;
      Master_Bus_Latency_Time_Exceeded <= (Master_Bus_Latency_Timer[7:0]  // set
                                           == master_latency_value[7:0])
                                    | Master_Bus_Latency_Time_Exceeded;  // hold
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
// NOTE: The PCI Spec says that the Byte Enables driven by the Master
// must be valid on all clocks.  Therefore, the Master cannot
// allow one transfer to complete until it knows that both data for
// that transfer is available AND byte enables for the next transfer
// are available.  This requirement means that this logic must be
// aware of the top 2 entries in the Request FIFO.  The Master might
// need to do a master disconnect, and a later reference retry,
// solely because the Byte Enables for the NEXT reference aren't
// available early enough.
// See the PCI Local Bus Spec Revision 2.2 section 3.2.2 and 3.3.1 for details.
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
//    MASTER_WAIT,        FIFO Empty           1      0    (Impossible?)
// Master Abort        X      X                0      1  -> MASTER_S_TAR
// Target Wait         0      0                1      0  -> MASTER_WAIT
// Target Data         1      0                1      0  -> MASTER_WAIT
// Target Last Data    1      1                1      0  -> MASTER_WAIT
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_WAIT,        FIFO non-Last Data   1      0
// Master Abort        X      X                0      1  -> MASTER_S_TAR
// Target Wait         0      0                1      1  -> MASTER_DATA_MORE
// Target Data         1      0                1      1  -> MASTER_DATA_MORE
// Target Last Data    1      1                0      1  -> MASTER_DATA_LAST
// Target DRA          0      1                0      1  -> MASTER_S_TAR
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_WAIT,        FIFO Last Data       1      0
// Master Abort        X      X                0      1  -> MASTER_S_TAR
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
// Handling Master Abort or Target Abort       0      0  -> MASTER_FLUSH
// Target Don't Care   X      X                0      0  -> MASTER_IDLE
//                    TRDY   STOP            FRAME   IRDY
//    MASTER_S_TAR,       FIFO Address         0      1 (and if Fast Back-to-Back)
// Handling Master Abort or Target Abort       0      0  -> MASTER_FLUSH
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

  parameter PCI_MASTER_IDLE      = 9'b000000001;  // Master in IDLE state
  parameter PCI_MASTER_ADDR      = 9'b000000010;  // Master Drives Address
  parameter PCI_MASTER_ADDR2     = 9'b000000100;  // Master Drives Address in 64-bit address mode
  parameter PCI_MASTER_WAIT      = 9'b000001000;  // Waiting for Master Data
  parameter PCI_MASTER_DATA_MORE = 9'b000010000;  // Master Transfers Data
  parameter PCI_MASTER_DATA_LAST = 9'b000100000;  // Master Transfers Last Data
  parameter PCI_MASTER_S_TAR     = 9'b001000000;  // Stop makes Turn Around
  parameter PCI_MASTER_DR_BUS    = 9'b010000000;  // Address Step or Bus Park
  parameter PCI_MASTER_FLUSHING  = 9'b100000000;  // Flushing Request FIFO
  reg    [8:0] PCI_Master_State;

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
    if (pci_reset_comb == 1'b1)
    begin
      PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
    end
    else
    begin
      case (PCI_Master_State[8:0])
      PCI_MASTER_IDLE:
        begin
// NOTE WORKING need to hop to MASTER_DR_BUS from IDLE somehow?
          if (Request_FIFO_Empty == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
          end
          else if (Request_FIFO_CONTAINS_ADDRESS == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master IDLE Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_ADDR:
        begin  // when 64-bit Address added, -> PCI_MASTER_ADDR2
          PCI_Master_State[8:0] <= PCI_MASTER_WAIT;
        end
      PCI_MASTER_ADDR2:
        begin  // Not implemented yet. Will be identical to Wait
          PCI_Master_State[8:0] <= PCI_MASTER_WAIT;
        end
      PCI_MASTER_WAIT:
        begin
          if (Request_FIFO_Empty == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_WAIT;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_WAIT;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_WAIT;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_MORE == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_DATA_MORE;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_LAST == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else  // Request_FIFO_CONTAINS_ADDRESS.  Bug
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master WAIT Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_DATA_MORE:
        begin
          if (Request_FIFO_Empty == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_WAIT;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Data More TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_MORE == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_DATA_MORE;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Data More TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_DATA_LAST == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_DATA_MORE;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_S_TAR;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
                $display ("PCI Master Data More TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else  // Request_FIFO_CONTAINS_ADDRESS.  Bug
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master Data More Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_DATA_LAST:
        begin
          if (Request_FIFO_Empty == 1'b1)
          begin
            case ({pci_trdy_in_prev, pci_stop_in_prev})
            TARGET_IDLE:      PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;
            TARGET_TAR:       PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
            TARGET_DATA_MORE: PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
            TARGET_DATA_LAST: PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
            default:
              begin
// synopsys translate_off
                PCI_Master_State[8:0] <= PCI_MASTER_WAIT;  // error
                $display ("PCI Master Data Last TRDY, STOP Unknown %x %x at time %t",
                           pci_trdy_in_prev, pci_stop_in_prev, $time);
// synopsys translate_on
              end
            endcase
          end
          else if (Request_FIFO_CONTAINS_ADDRESS == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_DATA_LAST;  // error
// synopsys translate_off
            $display ("PCI Master Data Last Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_S_TAR:
        begin
          if (Request_FIFO_Empty == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
          end
          else if (Request_FIFO_CONTAINS_ADDRESS == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master S_TAR Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_DR_BUS:
        begin
          if (Request_FIFO_Empty == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;
          end
          else if (Request_FIFO_CONTAINS_ADDRESS == 1'b1)
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_ADDR;
          end
          else // Request_FIFO_CONTAINS_DATA_????.  Bug
          begin
            PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
            $display ("PCI Master DR Bus Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
// synopsys translate_on
          end
        end
      PCI_MASTER_FLUSHING:
        begin
          PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // NOTE: WORKING
          $display ("PCI Master Flushing Fifo Contents Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
        end
      default:
        begin
          PCI_Master_State[8:0] <= PCI_MASTER_IDLE;  // error
// synopsys translate_off
          $display ("PCI Master State Machine Unknown %x at time %t",
                           PCI_Master_State[8:0], $time);
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

// The PCI Bus gets either data directly from the FIFO or it gets the stored
// address, which has been incrementing until the previous Target Retry was received.
  wire    Master_Select_Stored_Address;
  assign  pci_master_ad_out_next[31:0] = Master_Select_Stored_Address
                                       ? {Master_Retry_Address[31:2], 2'h0}
                                       : pci_request_fifo_data[31:0];
  assign  pci_cbe_l_out_next[3:0] =      Master_Select_Stored_Address
                                       ? Master_Retry_Command[3:0]
                                       : pci_request_fifo_cbe[3:0];

// As quickly as possible, decide whether to present new Master Control Info
//   on Master Control bus, or to continue sending old data.  The state machine
//   needs to know what happened too, so it can prepare the Control info for
//   next time.
// NOTE: IRDY and TRDY are very late.  3 nSec before clock edge!
// NOTE: The FRAME_Next and IRDY_Next signals are latched in the
//       outputs pad in the IO pad module.
  wire   [2:0] PCI_Next_FRAME_Code = 3'h0;  // NOTE: WORKING
  wire   [2:0] PCI_Next_IRDY_Code = 3'h0;  // NOTE: WORKING

// NOTE: WORKING what should happen during RETRIES
// NOTE: WORKING what should happen during FLUSHES

  assign  Master_Flushing_Request_FIFO = 0;  // NOTE: WORKING
  assign  Master_Writing_Status_Now = 0;  // NOTE: WORKING
  assign  Master_Asserting_IRDY_Now = 0;  // NOTE: WORKING
  assign  Master_Unloading_Request_Now = 0;  // NOTE: WORKING
  assign  Master_Retry_Address_Available = 0;  // NOTE: WORKING

  assign  pci_master_ad_out_oe_comb = 1'b0;  // NOTE WORKING
  assign  pci_cbe_out_oe_comb = 1'b0;  // NOTE WORKING
  assign  pci_frame_out_oe_comb = 1'b0;  // NOTE WORKING
  assign  pci_irdy_out_oe_comb = 1'b0;  // NOTE WORKING

  assign  Master_Force_Address_Data = 1'b0;  // NOTE WORKING
  assign  Master_Expects_TRDY = 1'b0;  // NOTE WORKING
  assign  Master_Requests_PERR = 1'b0;  // NOTE WORKING

  assign  pci_master_par_out_oe_comb = 1'b0;  // NOTE WORKING move to top-level?
  assign  pci_master_perr_out_oe_comb = 1'b0;  // NOTE WORKING
  assign  pci_master_serr_out_oe_comb = 1'b0;  // NOTE WORKING

  assign  Master_Select_Stored_Address = 1'b0;  // NOTE WORKING
  assign  Master_Grab_Address = 1'b0;  // NOTE WORKING
  assign  Master_Inc_Address = 1'b0;  // NOTE WORKING
  assign  Master_Got_Retry = 1'b0;  // NOTE WORKING
  assign  Master_Clear_Bus_Latency_Timer = 1'b0;  // NOTE WORKING
  assign  Master_Start_Master_Abort_Counter = 1'b0;  // NOTE WORKING

  assign  master_got_parity_error = 1'b0;  // NOTE WORKING
  assign  master_caused_serr = 1'b0;  // NOTE WORKING
  assign  master_caused_master_abort = 1'b0;  // NOTE WORKING
  assign  master_got_target_abort = 1'b0;  // NOTE WORKING
  assign  master_caused_parity_error = 1'b0;  // NOTE WORKING
  assign  master_asked_to_retry = 1'b0;  // NOTE WORKING
  assign  master_req_out = 1'b0;  // NOTE WORKING
  assign  pci_master_ad_en_next = 1'b0;  // NOTE WORKING
  assign  pci_cbe_out_en_next = 1'b0;  // NOTE WORKING
  assign  pci_master_par_out_next = 1'b0;  // NOTE WORKING
  assign  pci_master_perr_out_next = 1'b0;  // NOTE WORKING

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

