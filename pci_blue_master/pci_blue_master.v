//===========================================================================
// $Id: pci_blue_master.v,v 1.30 2001-08-06 00:30:14 bbeaver Exp $
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
//        section 3.2.2.1 for details.
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

`timescale 1ns/10ps

`define VERBOSE_MASTER_DEVICE

module pci_blue_master (
// Signals driven to control the external PCI interface
  pci_req_out_oe_comb, pci_req_out_next,
  pci_gnt_in_prev,     pci_gnt_in_critical,
  pci_master_ad_out_oe_comb, pci_master_ad_out_next,
  pci_cbe_out_oe_comb, pci_cbe_l_out_next,
  pci_frame_in_critical, pci_frame_in_prev,
  pci_frame_out_oe_comb, pci_frame_out_next,
  pci_irdy_in_critical, pci_irdy_in_prev,
  pci_irdy_out_oe_comb, pci_irdy_out_next,
  pci_devsel_in_prev,    
  pci_trdy_in_critical,    pci_trdy_in_prev,
  pci_stop_in_critical,    pci_stop_in_prev,
  pci_perr_in_prev,
  pci_serr_in_prev,
// Signals to control shared AD bus, Parity, and SERR signals
  Master_Force_AD_to_Address_Data_Critical,
  Master_Exposes_Data_On_TRDY,
  Master_Captures_Data_On_TRDY,
  Master_Forces_PERR,
  PERR_Detected_While_Master_Read,
// Signal to control Request pin if on-chip PCI devices share it
  Master_Forced_Off_Bus_By_Target_Abort,
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
  master_to_target_status_flush,
  master_to_target_status_available,
  master_to_target_status_unload,
  master_to_target_status_two_words_free,
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
  master_latency_value,
  pci_clk,
  pci_reset_comb
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

// Signals driven to control the external PCI interface
  output  pci_req_out_next;
  output  pci_req_out_oe_comb;
  input   pci_gnt_in_prev;
  input   pci_gnt_in_critical;
  output [PCI_BUS_DATA_RANGE:0] pci_master_ad_out_next;
  output  pci_master_ad_out_oe_comb;
  output [PCI_BUS_CBE_RANGE:0] pci_cbe_l_out_next;
  output  pci_cbe_out_oe_comb;
  input   pci_frame_in_critical;
  input   pci_frame_in_prev;
  output  pci_frame_out_next;
  output  pci_frame_out_oe_comb;
  input   pci_irdy_in_critical;
  input   pci_irdy_in_prev;
  output  pci_irdy_out_next;
  output  pci_irdy_out_oe_comb;
  input   pci_devsel_in_prev;
  input   pci_trdy_in_prev;
  input   pci_trdy_in_critical;
  input   pci_stop_in_prev;
  input   pci_stop_in_critical;
  input   pci_perr_in_prev;
  input   pci_serr_in_prev;
// Signals to control shared AD bus, Parity, and SERR signals
  output  Master_Force_AD_to_Address_Data_Critical;
  output  Master_Exposes_Data_On_TRDY;
  output  Master_Captures_Data_On_TRDY;
  output  Master_Forces_PERR;
  input   PERR_Detected_While_Master_Read;
// Signal to control Request pin if on-chip PCI devices share it
  output  Master_Forced_Off_Bus_By_Target_Abort;
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  input  [2:0] pci_request_fifo_type;
  input  [PCI_BUS_CBE_RANGE:0] pci_request_fifo_cbe;
  input  [PCI_BUS_DATA_RANGE:0] pci_request_fifo_data;
  input   pci_request_fifo_data_available_meta;
  input   pci_request_fifo_two_words_available_meta;
  output  pci_request_fifo_data_unload;
  input   pci_request_fifo_error;  // NOTE: MAKE SURE THIS IS NOTED SOMEWHERE
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  output [2:0] master_to_target_status_type;
  output [PCI_BUS_CBE_RANGE:0] master_to_target_status_cbe;
  output [PCI_BUS_DATA_RANGE:0] master_to_target_status_data;
  output  master_to_target_status_flush;
  output  master_to_target_status_available;
  input   master_to_target_status_unload;
  input   master_to_target_status_two_words_free;
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
  input  [7:0] master_latency_value;
  input   pci_clk;
  input   pci_reset_comb;

// Forward references, stuffed here to make the rest of the code compact
  wire    prefetching_request_fifo_data;  // done
  wire    Master_Mark_Status_Entry_Flushed;
  reg     master_request_full;  // done
  wire    Master_Consumes_Request_FIFO_Data_Unconditionally_Critical;
  wire    Master_Consumes_Request_FIFO_If_TRDY;
  wire    master_to_target_status_loadable;
  wire    Master_Got_Retry;
  wire    Master_Clear_Master_Abort_Counter;
  wire    Master_Clear_Data_Latency_Counter;
  wire    Master_Clear_Bus_Latency_Timer;
  wire    proceed_with_new_address_plus_new_data;
  wire    proceed_with_stored_address_plus_new_data;
  wire    proceed_with_stored_address_plus_stored_data;
  wire    inc_stored_address;
  wire    Fast_Back_to_Back_Possible;
  wire    Master_Discards_Request_FIFO_Entry_After_Abort;

// The PCI Blue Master gets commands from the pci_request_fifo.
// There are 3 main types of entries:
// 1) Address/Data sequences which cause external PCI activity.
// 2) Config Accesses to the Local PCI Config Registers.
// 3) Write Fence tokens.  These act just like Register Reverences.
//
// The Host Interface is required to send Requests in this order:
//   Address, optionally several Data's, Data_Last.  Sequences of Address-Address,
//   Data-Address, Data_Last-Data, or Data_Last-Data_Last are all illegal.
//
// The PCI Blue Master sends all of the commands over to the Target
//   as Status as soon as they are acted on.  This is so that the reader
//   of the pci_response_fifo can keep track of the Master's progress.

// Use standard FIFO prefetch trick to allow a single flop to control the
//   unloading of the whole FIFO.
  reg    [2:0] request_fifo_type_reg;
  reg    [PCI_BUS_CBE_RANGE:0] request_fifo_cbe_reg;
  reg    [PCI_BUS_DATA_RANGE:0] request_fifo_data_reg;
  reg     request_fifo_flush_reg;

  always @(posedge pci_clk)
  begin
    if (prefetching_request_fifo_data == 1'b1)
    begin  // latch whenever data available and not already full
      request_fifo_type_reg[2:0] <= pci_request_fifo_type[2:0];
      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0] <=
                      pci_request_fifo_cbe[PCI_BUS_CBE_RANGE:0];
      request_fifo_data_reg[PCI_BUS_DATA_RANGE:0] <=
                      pci_request_fifo_data[PCI_BUS_DATA_RANGE:0];
      request_fifo_flush_reg <= Master_Mark_Status_Entry_Flushed;
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
//       $display ("%m PCI Master prefetching data from Request FIFO %x %x %x, at time %t",
//                   pci_request_fifo_type[2:0], pci_request_fifo_cbe[PCI_BUS_CBE_RANGE:0],
//                   pci_request_fifo_data[PCI_BUS_DATA_RANGE:0], $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
    else if (prefetching_request_fifo_data == 1'b0)  // hold
    begin
      request_fifo_type_reg[2:0] <= request_fifo_type_reg[2:0];
      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0] <=
                      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0];
      request_fifo_data_reg[PCI_BUS_DATA_RANGE:0] <=
                      request_fifo_data_reg[PCI_BUS_DATA_RANGE:0];
      request_fifo_flush_reg <= request_fifo_flush_reg;
    end
// synopsys translate_off
    else
    begin
      request_fifo_type_reg[2:0] <= 3'hX;
      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0] <= `PCI_BUS_CBE_X;
      request_fifo_data_reg[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
      request_fifo_flush_reg <= 1'bX;
    end
// synopsys translate_on
  end

  wire    Master_Flushing_Housekeeping = prefetching_request_fifo_data
                      & (   (pci_request_fifo_type[2:0] ==  // unused
                                    PCI_HOST_REQUEST_SPARE)
                          | (pci_request_fifo_type[2:0] ==  // fence or register access
                                    PCI_HOST_REQUEST_INSERT_WRITE_FENCE));
  wire    Master_Consumes_This_Entry_Critical =
                        Master_Consumes_Request_FIFO_Data_Unconditionally_Critical
                      | Master_Flushing_Housekeeping;

// Master Request Full bit indicates when data prefetched on the way to PCI bus
// Single FLOP is used to control activity of this FIFO.
// NOTE: TRDY is VERY LATE.  This must be implemented to let TRDY operate quickly
// FIFO data is consumed if Master_Consumes_Request_FIFO_Data_Unconditionally_Critical
//                       or Master_Captures_Request_FIFO_If_TRDY and TRDY
// If not unloading and not full and no data,  not full
// If not unloading and not full and data,     full
// If not unloading and full and no data,      full
// If not unloading and full and data,         full
// If unloading and not full and no data,      not full
// If unloading and not full and data,         not full
// If unloading and full and no data,          not full
// If unloading and full and data,             full
  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      master_request_full <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      if (pci_trdy_in_critical == 1'b1)  // pci_trdy_in_critical is VERY LATE
      begin
        master_request_full <=
                      (   Master_Consumes_This_Entry_Critical
                        | Master_Consumes_Request_FIFO_If_TRDY)
                      ? (master_request_full & prefetching_request_fifo_data)   // unloading
                      : (master_request_full | prefetching_request_fifo_data);  // not unloading
      end
      else if (pci_trdy_in_critical == 1'b0)
      begin
        master_request_full <=
                          Master_Consumes_This_Entry_Critical
                      ? (master_request_full & prefetching_request_fifo_data)   // unloading
                      : (master_request_full | prefetching_request_fifo_data);  // not unloading
      end
// synopsys translate_off
      else
        master_request_full <= 1'bX;
// synopsys translate_on
    end
// synopsys translate_off
    else
      master_request_full <= 1'bX;
// synopsys translate_on
  end

// Deliver data to the IO pads when needed.
  wire   [2:0] pci_request_fifo_type_current =
                        prefetching_request_fifo_data
                      ? pci_request_fifo_type[2:0]
                      : request_fifo_type_reg[2:0];
  wire   [PCI_BUS_DATA_RANGE:0] pci_request_fifo_data_current =
                        prefetching_request_fifo_data
                      ? pci_request_fifo_data[PCI_BUS_DATA_RANGE:0]
                      : request_fifo_data_reg[PCI_BUS_DATA_RANGE:0];
  wire   [PCI_BUS_CBE_RANGE:0] pci_request_fifo_cbe_current =
                        prefetching_request_fifo_data
                      ? pci_request_fifo_cbe[PCI_BUS_CBE_RANGE:0]
                      : request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0];

// Create Data Available signals which depend on the FIFO, the Latch, AND the
//   input of the status datapath, which can prevent the unloading of data.
  wire    request_fifo_data_available_meta =
                        (   pci_request_fifo_data_available_meta
                          | master_request_full);  // available
  wire    request_fifo_two_words_available_meta =
                        (   pci_request_fifo_two_words_available_meta
                          | (   pci_request_fifo_data_available_meta
                              & master_request_full));  // available

// Calculate whether to unload data from the Request FIFO
  assign  prefetching_request_fifo_data = pci_request_fifo_data_available_meta
                                        & ~master_request_full
                                        & master_to_target_status_loadable;
  assign  pci_request_fifo_data_unload = prefetching_request_fifo_data;  // drive outputs

// Re-use Request FIFO Prefetch Buffer to send Signals from the Request FIFO
//   to the Target to finally insert the Status Info into the Response FIFO.
// The Master will only make progress when this Buffer between
//   Master and Target is empty.
// Target Status Full bit indicates when the Target must accept the Status data.
// NOTE: The status is set to the Target BEFORE, or at the same time, as it is
//       sent to the PCI Bus.  You can only know when the data is actually on the
//       bus by looking at the Master_Request_Full bit, not master_to_target_full.
  reg     master_to_target_status_full;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      master_to_target_status_full <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      master_to_target_status_full <= prefetching_request_fifo_data
                                    | (   master_to_target_status_full
                                        & ~master_to_target_status_unload);
    end
// synopsys translate_off
    else
      master_to_target_status_full <= 1'bX;
// synopsys translate_on
  end

// Create Buffer Available signal which can prevent the unloading of data.
  assign  master_to_target_status_loadable = ~master_to_target_status_full
                                           | master_to_target_status_unload;

// Send Status Data to Target.  This works because ALL request data goes
//   through the prefetch buffer, where it sits until it is replaced.
  assign  master_to_target_status_type[2:0] =                   // drive outputs
                      request_fifo_type_reg[2:0];
  assign  master_to_target_status_cbe[PCI_BUS_CBE_RANGE:0] =    // drive outputs
                      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0];
  assign  master_to_target_status_data[PCI_BUS_DATA_RANGE:0] =  // drive outputs
                      request_fifo_data_reg[PCI_BUS_DATA_RANGE:0];
  assign  master_to_target_status_flush = request_fifo_flush_reg;  // drive outputs
  assign  master_to_target_status_available = master_to_target_status_full;  // drive outputs

// State Machine keeping track of Request FIFO Retry Information.
// Retry Information is needed when the Target does a Retry with or without
//   data, or when the Master ends a Burst early because of lack of data.
// All Address and Data items which have been offered to the PCI interface
//   may need to be retried.
// Unfortunately, it is not possible to look at the IRDY/TRDY signals
//   directly to see if the Address or Data item has been passed onto
//   the bus.
// Fortunately, it is possible to look at the Request FIFO Prefetch
//   buffer to find the same information.
// If an Address or Data item is written to an empty Prefetch buffer and the
//   buffer stays empty, the item passed to the PCI bus immediately.
// If an Address or Data item is in a full Prefetch buffer and the full
//   bit goes from 1 to 0, that means the item was unloaded to the
//   PCI buffer.
// In both cases, the Address or Data must be captured from the Prefetch
//   buffer and held in case a Retry is needed.
// When an Address is captured, the next Data will need to be retried to
//   the same Address.
// Each time a subsequent Data item is captured, the Address must be
//   incremented.  This is because a Data item will only be issued to
//   the PCI bus after the previous Data was consumed.  The new
//   Data must go to the Address 4 greater than the previous Data item.

// Delay the Full Flop, to see when when it transitions from Full to Empty,
//   or whenever it does not become full because of bypass.  In both cases
//   it is time to capture Address or Data items.
// NOTE: These signals are delayed one clock from when the data goes onto the bus.
//   The address or data are captured from the Target Side of the reporting scheme.
  reg     Master_Previously_Full;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Master_Previously_Full <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      Master_Previously_Full <= master_request_full | prefetching_request_fifo_data;
    end
// synopsys translate_off
    else
    begin
      Master_Previously_Full <= 1'bX;
    end
// synopsys translate_on
  end

// This clock, the data previously in the delay element is being discarded.
  wire    Master_Capturing_Retry_Data = Master_Previously_Full  // notice that data
                                      & ~master_request_full;   // transferred to PCI bus

// Classify Address and Data just sent out onto PCI bus
  wire    Master_Issued_Address = Master_Capturing_Retry_Data  // used several places
                      & (   (request_fifo_type_reg[2:0] ==  // new address
                                    PCI_HOST_REQUEST_ADDRESS_COMMAND)
                          | (request_fifo_type_reg[2:0] ==  // new address
                                    PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR));
  wire    Master_Issued_Data = Master_Capturing_Retry_Data  // used several places
                      & (   (request_fifo_type_reg[2:0] ==  // new data
                                    PCI_HOST_REQUEST_W_DATA_RW_MASK)
                          | (request_fifo_type_reg[2:0] ==  // new data
                                    PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                          | (request_fifo_type_reg[2:0] ==  // new data
                                    PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR)
                          | (request_fifo_type_reg[2:0] ==  // new data
                                    PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR));

// Keep track of the present PCI Address, so the Master can restart references
//   if it receives a Target Retry.
// The bottom 2 bits of a PCI Address have special meaning to the
// PCI Master and PCI Target.  See the PCI Local Bus Spec
// Revision 2.2 section 3.2.2.1 and 3.2.2.2 for details.
// The PCI Master will never do a Burst when the command is an IO command.
// NOTE: if 64-bit addressing implemented, need to capture BOTH
//   halves of the address before data can be allowed to proceed.
// NOTE: Clever trick.  Don't latch the address here until the data has
//   been UNLOADED on the PCI side.  This indicates that it has been driven
//   to the external bus.
  reg    [PCI_BUS_DATA_RANGE:0] Master_Retry_Address;
  reg    [PCI_BUS_CBE_RANGE:0] Master_Retry_Command;
  reg    [2:0] Master_Retry_Address_Type;
  reg     Master_Retry_Write_Reg;

  always @(posedge pci_clk)
  begin
    if (Master_Issued_Address == 1'b1)  // hold or increment the Burst Address
    begin
      Master_Retry_Address_Type[2:0] <= request_fifo_type_reg[2:0];
      Master_Retry_Address[PCI_BUS_DATA_RANGE:0] <=
                         request_fifo_data_reg[PCI_BUS_DATA_RANGE:0]
                      & `PCI_BUS_Address_Mask;

      Master_Retry_Command[PCI_BUS_CBE_RANGE:0] <=
                      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0];
      Master_Retry_Write_Reg <= (   request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0]
                                  & PCI_COMMAND_ANY_WRITE_MASK) != `PCI_BUS_CBE_ZERO;
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
//      $display ("%m PCI Master capturing Retry Address from Status Register %x %x %x, at time %t",
//                  request_fifo_type_reg[2:0], request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0],
//                  request_fifo_data_reg[PCI_BUS_DATA_RANGE:0], $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
    else if (Master_Issued_Address == 1'b0)
    begin
      Master_Retry_Address_Type[2:0] <= Master_Retry_Address_Type[2:0];
      if (inc_stored_address == 1'b1)
      begin
        Master_Retry_Address[PCI_BUS_DATA_RANGE:0]   <=
                         Master_Retry_Address[PCI_BUS_DATA_RANGE:0]
                      + `PCI_BUS_Address_Step;
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
//      $display ("%m PCI Master incrementing Retry Address %x, at time %t",
//                  Master_Retry_Address[PCI_BUS_DATA_RANGE:0]
//                      + `PCI_BUS_Address_Step, $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
      end
      else if (inc_stored_address == 1'b0)
      begin
        Master_Retry_Address[PCI_BUS_DATA_RANGE:0] <=
                      Master_Retry_Address[PCI_BUS_DATA_RANGE:0];
      end
// synopsys translate_off
      else
        Master_Retry_Address[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
// synopsys translate_on
// If a Target Disconnect is received during a Memory Write and Invalidate,
//   the reference should be retried as a normal Memory Write.
//   See the PCI Local Bus Spec Revision 2.2 section 3.3.3.2.1 for details.
      if ((Master_Got_Retry == 1'b1)
           & (Master_Retry_Command[PCI_BUS_CBE_RANGE:0] ==
                 PCI_COMMAND_MEMORY_WRITE_INVALIDATE))
        Master_Retry_Command[PCI_BUS_CBE_RANGE:0] <= PCI_COMMAND_MEMORY_WRITE;
      else
        Master_Retry_Command[PCI_BUS_CBE_RANGE:0] <=
                      Master_Retry_Command[PCI_BUS_CBE_RANGE:0];
      Master_Retry_Write_Reg <= Master_Retry_Write_Reg;
    end
// synopsys translate_off
    else
    begin
      Master_Retry_Address_Type[2:0] <= 3'hX;
      Master_Retry_Address[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
      Master_Retry_Command[PCI_BUS_CBE_RANGE:0] <= `PCI_BUS_CBE_X;
      Master_Retry_Write_Reg <= 1'bX;
    end
// synopsys translate_on
  end

// Create early version of Write signal to be used to de-OE AD bus after Addr
  wire    Master_Retry_Write = Master_Issued_Address
                             ? ((   request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0]
                                  & PCI_COMMAND_ANY_WRITE_MASK) != `PCI_BUS_CBE_ZERO)
                             : Master_Retry_Write_Reg;

// Grab Data to allow retries if disconnect without data
// NOTE: Clever trick.  Don't latch the address here until the data has
//   been UNLOADED on the PCI side.  This indicates that it has been driven
//   to the external bus.
  reg    [PCI_BUS_DATA_RANGE:0] Master_Retry_Data;
  reg    [PCI_BUS_CBE_RANGE:0] Master_Retry_Data_Byte_Enables;
  reg    [2:0] Master_Retry_Data_Type;

  always @(posedge pci_clk)
  begin
    if (Master_Issued_Data == 1'b1)  // hold or increment the Burst Address
    begin
      Master_Retry_Data_Type[2:0] <= request_fifo_type_reg[2:0];
      Master_Retry_Data[PCI_BUS_DATA_RANGE:0] <=
                      request_fifo_data_reg[PCI_BUS_DATA_RANGE:0];
      Master_Retry_Data_Byte_Enables[PCI_BUS_CBE_RANGE:0] <=
                      request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0];
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
//      $display ("%m PCI Master capturing Retry Data from Status Register %x %x %x, at time %t",
//                  request_fifo_type_reg[2:0], request_fifo_cbe_reg[PCI_BUS_CBE_RANGE:0],
//                  request_fifo_data_reg[PCI_BUS_DATA_RANGE:0], $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
    else if (Master_Issued_Data == 1'b0)
    begin
      Master_Retry_Data_Type[2:0] <= Master_Retry_Data_Type[2:0];
      Master_Retry_Data[PCI_BUS_DATA_RANGE:0] <=
                      Master_Retry_Data[PCI_BUS_DATA_RANGE:0];
      Master_Retry_Data_Byte_Enables[PCI_BUS_CBE_RANGE:0] <=
                      Master_Retry_Data_Byte_Enables[PCI_BUS_CBE_RANGE:0];
    end
// synopsys translate_off
    else
    begin
      Master_Retry_Data_Type[2:0] <= 3'hX;
      Master_Retry_Data[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
      Master_Retry_Data_Byte_Enables[PCI_BUS_CBE_RANGE:0] <= `PCI_BUS_CBE_X;
    end
// synopsys translate_on
  end

// Master Aborts are detected when the Master asserts FRAME, and does
// not see DEVSEL in a timely manner.  See the PCI Local Bus Spec
// Revision 2.2 section 3.3.3.1 for details.
  reg    [2:0] Master_Abort_Counter;
  reg     Master_Got_Devsel, Master_Abort_Detected_Reg;

  always @(posedge pci_clk)
  begin
    if (Master_Clear_Master_Abort_Counter == 1'b1)
    begin
      Master_Abort_Counter[2:0] <= 3'h0;
      Master_Got_Devsel <= 1'b0;
      Master_Abort_Detected_Reg <= 1'b0;
    end
    else if (Master_Clear_Master_Abort_Counter == 1'b0)
    begin
      Master_Abort_Counter[2:0] <= Master_Abort_Counter[2:0] + 3'h1;
      Master_Got_Devsel <= pci_devsel_in_prev | Master_Got_Devsel;
      Master_Abort_Detected_Reg <= Master_Abort_Detected_Reg
                      | (   ~Master_Got_Devsel
                          & (Master_Abort_Counter[2:0] >= 3'h5));
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
      if (   (Master_Abort_Detected_Reg == 1'b0)
           & (~Master_Got_Devsel & (Master_Abort_Counter[2:0] >= 3'h5))
           & ~Master_Clear_Master_Abort_Counter)
        $display ("%m PCI Master Abort detected, at time %t", $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
// synopsys translate_off
    else
    begin
      Master_Abort_Counter[2:0] <= 3'hX;
      Master_Got_Devsel <= 1'bX;
      Master_Abort_Detected_Reg <= 1'bX;
    end
// synopsys translate_on
  end

  wire    Master_Abort_Detected =  Master_Abort_Detected_Reg
                                & ~Master_Clear_Master_Abort_Counter;

// Master Data Latency Counter.  Must make progress within 8 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.2 for details.
// NOTE: This counter can be sloppy, as long as it never takes too LONG to
//   time out.  This is because I don't expect it to ever be used.  I
//   expect the Master interface to always have data available in a timely
//   fashion.  If the timer times out early, then extra retries will be
//   done.  Since this is unlikely, let it happen without worry.
  reg    [2:0] Master_Data_Latency_Counter;
  reg     Master_Data_Latency_Disconnect_Reg;

  always @(posedge pci_clk)
  begin
    if (Master_Clear_Data_Latency_Counter == 1'b1)
    begin
      Master_Data_Latency_Counter[2:0] <= 3'h0;
      Master_Data_Latency_Disconnect_Reg <= 1'b0;
    end
    else if (Master_Clear_Data_Latency_Counter == 1'b0)
    begin
      Master_Data_Latency_Counter[2:0] <= Master_Data_Latency_Counter[2:0] + 3'h1;
      Master_Data_Latency_Disconnect_Reg <= Master_Data_Latency_Disconnect_Reg
                      | (Master_Data_Latency_Counter[2:0] >= 3'h4);
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
      if (   (Master_Data_Latency_Disconnect_Reg == 1'b0)
           & (Master_Data_Latency_Counter[2:0] >= 3'h4)
           & ~Master_Clear_Data_Latency_Counter )
        $display ("%m PCI Master Data Latency Disconnect detected, at time %t", $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
// synopsys translate_off
    else
    begin
      Master_Data_Latency_Counter[2:0] <= 3'hX;
      Master_Data_Latency_Disconnect_Reg <= 1'bX;
    end
// synopsys translate_on
  end

  wire    Master_Data_Latency_Disconnect =  Master_Data_Latency_Disconnect_Reg
                                         & ~Master_Clear_Data_Latency_Counter;

// The Master Bus Latency Counter is needed to force the Master off the bus
//   in a timely fashion if it is in the middle of a burst when it's Grant is
//   removed.  See the PCI Local Bus Spec Revision 2.2 section 3.5.4 for details.
  reg    [7:0] Master_Bus_Latency_Timer;
  reg     Master_Bus_Latency_Disconnect;

  always @(posedge pci_clk)
  begin
    if (Master_Clear_Bus_Latency_Timer == 1'b1)
    begin
      Master_Bus_Latency_Timer[7:0]    <= 8'h00;
      Master_Bus_Latency_Disconnect <= 1'b0;
    end
    else if (Master_Clear_Bus_Latency_Timer == 1'b0)
    begin
      Master_Bus_Latency_Timer[7:0] <= pci_gnt_in_prev ? 8'h00
                                     : Master_Bus_Latency_Timer[7:0] + 8'h01;
      Master_Bus_Latency_Disconnect <= Master_Bus_Latency_Disconnect
                      | (Master_Bus_Latency_Timer[7:0]
                                 == master_latency_value[7:0]);
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
      if (   (Master_Bus_Latency_Disconnect == 1'b0)
           & (Master_Bus_Latency_Timer[7:0]
                                 == master_latency_value[7:0]))
        $display ("%m PCI Master Bus Latency Disconnect detected, at time %t", $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
// synopsys translate_off
    else
    begin
      Master_Bus_Latency_Timer[7:0] <= 8'hXX;
      Master_Bus_Latency_Disconnect <= 1'bX;
    end
// synopsys translate_on
  end

// EXTREME NIGHTMARE.  A PCI Master must assert Valid Write Enables
//   on all clocks, EVEN if IRDY is not asserted.  See the PCI Local
//   Bus Spec Revision 2.2 section 3.2.2 and 3.3.1 for details.
//   This means that the Master CAN'T assert an Address until the NEXT
//   Data Strobes are available, and can't assert IRDY on data unless
//   the Data is either the LAST data, or the NEXT data is available.
//   In the case of a Timeout, the Master has to convert a Data into
//   a Data_Last, so that it doesn't need to come up with the NEXT
//   Data Byte Enables.  The reference can only be continued once the
//   late data becomes available.
//
// The Request FIFO can be unloaded only of ALL of these three things are true:
// 1) Room available in Status FIFO to accept data
// 2) Address + Next Data, or Data + Next Data, or Data_Last, or Reg_Ref,
//    or Fence, in FIFO
// 3) If Data Phase, External Device on PCI bus allows transfer using TRDY,
//    otherwise send data immediately into PCI buffers.
// Other logic will mix in the various timeouts which can happen.

// Classify the activity commanded in the head of the Request FIFO.  In some
//   cases, the entry AFTER the first word needs to be known before the
//   entry can properly be classified.  If so, pertend that the FIFO is
//   empty until the needed data is available.

// Either Address in FIFO plus next Data in FIFO containing Byte Strobes,
//   or Stored Address plus next Data in FIFO containing Byte Strobes,
//   or Stored Address plus Stored Data containing Byte Strobes.

  wire   [2:0] Next_Request_Type = proceed_with_new_address_plus_new_data
                      ? pci_request_fifo_type_current[2:0]
                      : Master_Retry_Address_Type[2:0];

  wire    Request_FIFO_CONTAINS_ADDRESS =
               master_enable  // only start (or retry) a reference if enabled
             & master_to_target_status_loadable
             & master_to_target_status_two_words_free  // room for status to Target
             & (   (   proceed_with_new_address_plus_new_data
                     & request_fifo_two_words_available_meta)  // address plus data
                 | (   proceed_with_stored_address_plus_new_data
                     & request_fifo_data_available_meta)  // stored address plus data
                 | proceed_with_stored_address_plus_stored_data)  // both stored
             & (   (Next_Request_Type[2:0] ==
                                PCI_HOST_REQUEST_ADDRESS_COMMAND)
                 | (Next_Request_Type[2:0] ==
                                PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR));

// Classify PCI Command to decide whether to do address stepping or Config references
  wire   [PCI_BUS_CBE_RANGE:0] Next_Request_Command =
                        proceed_with_new_address_plus_new_data
                      ? pci_request_fifo_cbe_current[PCI_BUS_CBE_RANGE:0]
                      : Master_Retry_Command[PCI_BUS_CBE_RANGE:0];

  wire    Master_Doing_Config_Reference =
               (   (Next_Request_Command[PCI_BUS_CBE_RANGE:0] ==
                                PCI_COMMAND_CONFIG_READ)  // captured data used
                 | (Next_Request_Command[PCI_BUS_CBE_RANGE:0] ==
                                PCI_COMMAND_CONFIG_WRITE));  // captured data used

// Either Data or Data Last must follow the Address item
  wire   [2:0] Next_Data_Type =
                        (   proceed_with_new_address_plus_new_data
                          | proceed_with_stored_address_plus_new_data)
                      ? pci_request_fifo_type_current[2:0]
                      : Master_Retry_Data_Type[2:0];

  wire    Request_FIFO_CONTAINS_DATA_TWO_MORE =
               master_to_target_status_loadable
             & master_to_target_status_two_words_free  // room for status to Target
             & (   (   (   proceed_with_new_address_plus_new_data
                         | proceed_with_stored_address_plus_new_data)
                     & request_fifo_two_words_available_meta)
                 | (   proceed_with_stored_address_plus_stored_data
                     &  request_fifo_data_available_meta) )
             & (   (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK)
                 | (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR));

  wire    Request_FIFO_CONTAINS_DATA_MORE =
               master_to_target_status_loadable  // room for status to Target
             & (   (   (   proceed_with_new_address_plus_new_data
                         | proceed_with_stored_address_plus_new_data)
                     & request_fifo_data_available_meta)
                 | (   proceed_with_stored_address_plus_stored_data) )
             & (   (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK)
                 | (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR));

  wire    Request_FIFO_CONTAINS_DATA_LAST =
               master_to_target_status_loadable  // room for status to Target
             & (   (   (   proceed_with_new_address_plus_new_data
                         | proceed_with_stored_address_plus_new_data)
                     & request_fifo_data_available_meta)
                 | (   proceed_with_stored_address_plus_stored_data) )
             & (   (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                 | (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR));

// The Master State Machine as described in the PCI Local Bus Spec
//   Revision 2.2 Appendix B.
// No Lock State Machine is implemented.
// This design only supports a 32-bit FIFO.
// This design supports only 32-bit addresses, no Dual-Address cycles.
// This design supports only the 32-bit PCI bus.
// This design does not implement Interrupt Acknowledge Cycles.
// This design does not implement Special Cycles.
// This design does not enforce any Data rules for Memory Write and Invalidate.
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
//   PCI_MASTER_MORE_PENDING state.
//
// At the end of the address phase or a wait state, the Master
//   will either assert FRAME with IRDY to indicate that data is
//   ready and that more data will be available, or it will assert
//   no FRAME and IRDY to indicate that the last data is available.
//   The Data phase will end when the Target indicates that a
//   Target Disconnect with no data or a Target Abort has occurred.
//   The Target can also indicate that this should be a target
//   disconnect with data.  This is also the PCI_MASTER_MORE_PENDING state.
//
// In some situations, like when a Master Abort happens, or when
//   certain Target Aborts happen, the Master will have to transition
//   om asserting FRAME and not IRDY to no FRAME and IRDY, to let
//   the target end the transfer state sequence correctly.
//   This is the PCI_MASTER_STOP_TURN state
//
// There is one other thing to mention (if not covered above).  Sometimes
//   the Master may have a large burst, and the Target may accept it.
//   As the burst proceeds, one of 2 things may make the burst end in
//   an unusual way.  1) Master data not available soon enough, causing
//   master to time itself off the bus, or 2) GNT removed, causing
//   master to have to get off bus when the Latency Timer runs out.
//   In both cases, the Master has to fake a Last Data Transfer, then
//   has to re-arbitrate for the bus.  It must then continue the transfer,
//   using the incremented DMA address.  It acts partially like it had
//   received a Target Retry, but with itself causing the disconnect.
//
// Here is my interpretation of the Master State Machine:
//
// The Master is in one of 3 states when transferring data:
// 1) Waiting,
// 2) Transferring data with more to come,
// 3) Transferring the last Data item.
//
// NOTE: The PCI Spec says that the Byte Enables driven by the Master
//   must be valid on all clocks.  Therefore, the Master cannot
//   allow one transfer to complete until it knows that both data for
//   that transfer is available AND byte enables for the next transfer
//   are available.  This requirement means that this logic must be
//   aware of the top 2 entries in the Request FIFO.  The Master might
//   need to do a master disconnect, and a later reference retry,
//   solely because the Byte Enables for the NEXT reference aren't
//   available early enough.  See the PCI Local Bus Spec Revision 2.2
//   section 3.2.2 and 3.3.1 for details.
//
// The Request FIFO can indicate that it
// 1) contains no Data,
// 2) contains Data which is not the last,
// 3) contains the last Data
//
// When the Result FIFO has no room, this holds off Master State Machine
// activity the same as if no Write Data or Read Strobes were available.
//
// The Target can say that it wants a Wait State, that it wants
// to transfer Data, that it wants to transfer the Last Data,
// or that it wants to do a Disconnect, Retry, or Target Abort.
// (This last condition will be called Target DRA below.)
//
// NOTE: In all cases, the FRAME and IRDY signals are calculated
//   based on the TRDY and STOP signals, which are very late and very
//   timing critical.
// The functions will be implemented as a 4-1 MUX using TRDY and STOP
//   as the selection variables.
// The inputs to the FRAME and IRDY MUX's will be decided based on the state
//   the Master is in, and also on the contents of the Request FIFO.

// State Variables are closely related to PCI Control Signals:
// This nightmare is actually the product of 3 State Machines: PCI, R/W, Retry A/D
//  They are (in order) CBE_OE, FRAME_L, IRDY_L, State_[1,0]
  parameter PCI_MASTER_IDLE              = 5'b0_00_00;  // 00 Master in IDLE state
  parameter PCI_MASTER_PARK              = 5'b1_00_00;  // 10 Bus Park

  parameter PCI_MASTER_STEP              = 5'b1_00_01;  // 11 Address Step

  parameter PCI_MASTER_ADDR              = 5'b1_10_00;  // 18 Master Drives Address
  parameter PCI_MASTER_ADDR64            = 5'b1_10_01;  // 19 Master Drives Address in 64-bit Address mode

  parameter PCI_MASTER_LAST_PENDING      = 5'b1_10_11;  // 1B Sending Last Data as First Word
  parameter PCI_MASTER_MORE_PENDING      = 5'b1_10_10;  // 1A Waiting for Master Data

  parameter PCI_MASTER_DATA_MORE         = 5'b1_11_00;  // 1C Master Transfers Data

  parameter PCI_MASTER_NODATA_TURN       = 5'b1_01_00;  // 14 Target Transfers More Data as Last, then No Data
  parameter PCI_MASTER_STOP_TURN         = 5'b1_01_01;  // 15 Target Abort or Disconnect makes Turn Around

  parameter PCI_MASTER_DATA_LAST         = 5'b1_01_10;  // 16 Master Transfers Last Data
  parameter PCI_MASTER_DATA_MORE_TO_LAST = 5'b1_01_11;  // 17 Master Transfers Regular Data as Last

  parameter PCI_MASTER_LAST_IDLE         = 5'b0_00_01;  // 01 Master goes Idle, undriving bus immediately

  parameter MS_Range = 4;
  parameter MS_X = {(MS_Range+1){1'bX}};

// Classify the activity of the External Target.
// These correspond to            {trdy, stop}
  parameter TARGET_IDLE             = 2'b00;
  parameter TARGET_TAR              = 2'b01;
  parameter TARGET_DATA_MORE        = 2'b10;
  parameter TARGET_DATA_LAST        = 2'b11;

// Experience with the PCI Master Interface teaches that the signals
//   TRDY and STOP are extremely time critical.  These signals cannot be
//   latched in the IO pads.  The signals must be acted upon by the
//   Master State Machine as combinational inputs.
//
// The combinational logic is below.  This feeds into an Output Flop
//   which is right at the IO pad.  The State Machine uses the DEVSEL,
//   TRDY, and STOP signals which are latched in the input pads.
//   Therefore, all the fast stuff is in the gates below this case statement.

// NOTE:  The Master is not allowed to drive FRAME unless GNT is asserted.
// NOTE:  GNT_L is VERY LATE.  (However, it is not as late as the signals
//   TRDY_L and STOP_L.)    Make sure that this logic places the GNT
//   dependency on the fast branch.  See the PCI Local Bus Spec
//   Revision 2.2 section 3.4.1 and 7.6.4.2 for details.
// NOTE:  The Master is not allowed to take the bus from someone else until
//   FRAME and IRDY are both unasserted.  When fast back-to-back transfers
//   are happening, the state machine can drive Frame when it is driving
//   IRDY the previous clock.

// NOTE: FRAME and IRDY are VERY LATE.  This logic is in the critical path.
// See the PCI Local Bus Spec Revision 2.2 section 3.4.1 for details.

// NOTE: WORKING: rewrite state machine to have case ({pci_trdy_in, pci_stop_in})
//    right before the flops.  Make 4 functions from the 1 function below.

// Given a present Master State and all appropriate inputs, calculate the next state.
// Here is how to think of it for now: When a clock happens, this says what to do now
function [MS_Range:0] Master_Next_State;
  input  [MS_Range:0] Master_Present_State;
  input   bus_available_critical;
  input   FIFO_CONTAINS_ADDRESS;
  input   Doing_Config_Reference;
  input   FIFO_CONTAINS_DATA_TWO_MORE;
  input   FIFO_CONTAINS_DATA_MORE;
  input   FIFO_CONTAINS_DATA_LAST;
  input   Master_Abort;
  input   Timeout_Forces_Disconnect;
  input   trdy_in;
  input   stop_in;
  input   Back_to_Back_Possible;

  begin
// synopsys translate_off
      if (   ( $time > 0)
           & (   ((trdy_in ^ trdy_in) === 1'bX)
               | ((stop_in ^ stop_in) === 1'bX)))
      begin
        Master_Next_State[MS_Range:0] = MS_X;  // error
        $display ("*** %m PCI Master Wait TRDY, STOP Unknown %x %x at time %t",
                    trdy_in, stop_in, $time);
      end
      else
// synopsys translate_on

      case (Master_Present_State[MS_Range:0])  // synopsys parallel_case
      PCI_MASTER_IDLE:
        begin
          if (bus_available_critical == 1'b1)
          begin                  // external_pci_bus_available_critical is VERY LATE
            if (FIFO_CONTAINS_ADDRESS == 1'b0)  // bus park
              Master_Next_State[MS_Range:0] = PCI_MASTER_PARK;  // 1
            else if (Doing_Config_Reference == 1'b1)
              Master_Next_State[MS_Range:0] = PCI_MASTER_STEP;  // 2
            else  // must be regular reference.
              Master_Next_State[MS_Range:0] = PCI_MASTER_ADDR;  // 3
          end
          else
            Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // 4
        end
      PCI_MASTER_PARK:
        begin
          if (bus_available_critical == 1'b1)  // only needs GNT, but this OK
          begin                  // external_pci_bus_available_critical is VERY LATE
            if (FIFO_CONTAINS_ADDRESS == 1'b0)  // bus park
              Master_Next_State[MS_Range:0] = PCI_MASTER_PARK;  // 5
            else if (Doing_Config_Reference == 1'b1)
              Master_Next_State[MS_Range:0] = PCI_MASTER_STEP;  // 6
            else  // must be rgular reference.
              Master_Next_State[MS_Range:0] = PCI_MASTER_ADDR;  // 7
          end
          else
            Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // 8
        end
      PCI_MASTER_STEP:
        begin                    // external_pci_bus_available_critical is VERY LATE
          if (bus_available_critical == 1'b1)  // only needs GNT, but this OK
            Master_Next_State[MS_Range:0] = PCI_MASTER_ADDR;  // 9
          else
            Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // 10
        end
      PCI_MASTER_ADDR:
        begin  // when 64-bit Address added, -> PCI_MASTER_ADDR64
          if (FIFO_CONTAINS_DATA_LAST == 1'b1)
            Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_PENDING;  // 11
          else
            Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;  // 12
        end
      PCI_MASTER_ADDR64:
        begin  // Not implemented yet. Will be identical to Addr above + Wait
          if (FIFO_CONTAINS_DATA_LAST == 1'b1)
            Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_PENDING;  // 13
          else
            Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;  // 14
        end
// Enter LAST_PENDING state when this knows a Last Data is next.  Want to keep
//   the timing the same as for normal data transfers
      PCI_MASTER_LAST_PENDING:
        begin
            Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_LAST;  // Covered
        end
// Enter MORE_PENDING state when Master has 1 data item available, but needs a second.
// The second item is needed because the Byte Strobes must be available immediately
//   when the TRDY signal consumes the first data item.
      PCI_MASTER_MORE_PENDING:
        begin
          if (Master_Abort == 1'b1)
          begin
            Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;  // 15
          end
          else if (   (FIFO_CONTAINS_DATA_MORE == 1'b0)
                    & (FIFO_CONTAINS_DATA_LAST == 1'b0)
                    & (Timeout_Forces_Disconnect == 1'b0))  // no Master data or bus removed
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;       // 16
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;          // 17
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;       // 18
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 19
            `NO_DEFAULT;
            endcase
          end
          else if (Timeout_Forces_Disconnect == 1'b1)  // NOTE: shortcut; even if no data
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 20
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;          // 21
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 22
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 23
            `NO_DEFAULT;
            endcase
          end
          else if (   (FIFO_CONTAINS_DATA_MORE == 1'b1)
                    | (FIFO_CONTAINS_DATA_LAST == 1'b1))
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;          // 24
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;          // 25
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;          // 26
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 27
            `NO_DEFAULT;
            endcase
          end
          else  // Fifo has something wrong with it.  Bug.
          begin
            Master_Next_State[MS_Range:0] = MS_X;  // error
// synopsys translate_off
            $display ("*** %m PCI Master More Pending Fifo Contents Unknown %x %x %x at time %t",
                           Master_Next_State[MS_Range:0],
                           FIFO_CONTAINS_DATA_MORE, FIFO_CONTAINS_DATA_LAST, $time);
// synopsys translate_on
          end
        end
// Enter Data_More State when Master ready to send non-last Data, plus 1 more data item.
      PCI_MASTER_DATA_MORE:
        begin
          if (Master_Abort == 1'b1)
          begin
            Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;  // 28
          end
          else if (   (FIFO_CONTAINS_DATA_TWO_MORE == 1'b0)
                    & (FIFO_CONTAINS_DATA_LAST == 1'b0)  // no Master data ready
                    & (Timeout_Forces_Disconnect == 1'b0))  // no Master data or bus removed
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;     // 29
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;     // 30
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;  // 31
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_NODATA_TURN;   // 32
            `NO_DEFAULT;
            endcase
          end
          else if (FIFO_CONTAINS_DATA_LAST == 1'b1)
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 33
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;    // 34
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_LAST;    // 35
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_NODATA_TURN;  // 36
            `NO_DEFAULT;
            endcase
          end
          else if (Timeout_Forces_Disconnect == 1'b1)  // NOTE: shortcut; even if no data
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 37
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;    // 38
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 39 bug?
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_NODATA_TURN;  // 40
            `NO_DEFAULT;
            endcase
          end
          else if (FIFO_CONTAINS_DATA_TWO_MORE == 1'b1)
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 41
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;    // 42
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 43
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_NODATA_TURN;  // 44
            `NO_DEFAULT;
            endcase
          end
          else  // Fifo has something wrong with it.  Bug.
          begin
            Master_Next_State[MS_Range:0] = MS_X;  // error
// synopsys translate_off
            $display ("*** %m PCI Master Data More Fifo Contents Unknown %x at time %t",
                           Master_Next_State[MS_Range:0], $time);
// synopsys translate_on
          end
        end
// Enter NODATA_TURN State when Master says More, but Target says Last
// The present data is transferred, the next data is not.
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_NODATA_TURN:
        begin
          Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // Covered
        end
// Enter STOP_TURN when Master asserting FRAME and either IRDY or not IRDY,
//   and either a Master Abort happens, or a Target Abort happens, or a
//   Target Retry with no data transferred happens.
// The waiting data is not transferred.
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_STOP_TURN:
        begin
          Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // Covered
        end
// Enter Last State when Master ready to send Last Data
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_DATA_LAST:
        begin
          if (Master_Abort == 1'b1)
          begin
            Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 45
          end
          else if (   (FIFO_CONTAINS_ADDRESS == 1'b0)
                    | (   (FIFO_CONTAINS_ADDRESS == 1'b1)
                        & (Doing_Config_Reference == 1'b1) )
                    | (Back_to_Back_Possible == 1'b0))  // go idle
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_LAST;  // 46
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 47
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;       // 48
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;       // 49
            `NO_DEFAULT;
            endcase
          end
          else if (   (FIFO_CONTAINS_ADDRESS == 1'b1)
                    & (Doing_Config_Reference == 1'b0)
                    & (Back_to_Back_Possible == 1'b1))  // don't be tricky on config refs.
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_LAST;  // 50
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 51
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_ADDR;       // 52
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_ADDR;       // 53
            `NO_DEFAULT;
            endcase
          end
          else  // Fifo has something wrong with it.  Bug.
          begin
            Master_Next_State[MS_Range:0] = MS_X;  // error
// synopsys translate_off
            $display ("*** %m PCI Master Data More Fifo Contents Unknown %x at time %t",
                           Master_Next_State[MS_Range:0], $time);
// synopsys translate_on
          end
        end
// Enter MORE_TO_LAST State for 1 of several reasons:
// 1) Master waiting for second Data to become available, and Target says early Last.
//      Make the datain escrow into an early Last.
// 2) Master waiting for Target to accept More Data, and bus timeout occurs,
//      and Target says More.  Make the NEW data into an early Last.
// The data sent is sent as a Last Data, even if it is a More Data.
// NOTE in case 2 above, the LAST might terminate with a STOP!
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_DATA_MORE_TO_LAST:
        begin
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_TO_LAST;  // 54
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 55
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;       // 56
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;       // 57
            `NO_DEFAULT;
            endcase
          end
        end
// Enter LAST_IDLE when Master asserting IRDY and not FRAME,
//   and either a Master Abort happens, or a Target Abort happens, or a
//   Target Retry with no data transferred happens.
// This state is the same as STOP_TURN, except CBE, Data, and IRDY are not driven.
// The waiting data is not transferred.
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_LAST_IDLE:
        begin
          Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // Covered
        end
      default:
        begin
          Master_Next_State[MS_Range:0] = MS_X;  // error
// synopsys translate_off
          if ($time > 0)
            $display ("*** %m PCI Master State Machine Unknown %x at time %t",
                           Master_Next_State[MS_Range:0], $time);
// synopsys translate_on
        end
      endcase
  end
endfunction

// Start a reference when the bus is idle, or immediately if fast back-to-back.
// pci_frame_in_critical and pci_irdy_in_critical are VERY LATE.
// pci_gnt_in_critical is VERY LATE, but not as late as the other two.
// NOTE: WORKING: Very Subtle point.  The PCI Master may NOT look at the value
//   of signals it drove itself the previous clock.  The driver of a PCI bus
//   receives the value it drove later than all other devices.  See the PCI
//   Local Bus Spec Revision 2.2 section 3.10 item 9 for details.
//   FRAME isn't a problem, because it is driven 1 clock before IRDY.
//   This must therefore NOT look at IRDY unless it very sure that the the
//   data is constant for 2 clocks.  How?
// NOTE: It seems that FRAME and IRDY in must use the output value when they are driving
// NOTE: WORKING: Make sure Frame and IRDY are internally fed back when locally driven
  wire    external_pci_bus_available_critical = pci_gnt_in_critical
                        & ~pci_frame_in_critical & ~pci_irdy_in_critical;

// State Machine controlling the PCI Master.
//   Every clock, this State Machine transitions based on the LATCHED
//   versions of TRDY and STOP.  At the same time, combinational logic
//   below has already sent out the NEXT info to the PCI bus.
//  (These two actions had better be consistent.)
// The way to think about this is that the State Machine reflects the
//   PRESENT state of the PCI wires.  When you are in the Address state,
//   the Address is valid on the bus.
  reg    [MS_Range:0] PCI_Master_State;

  wire   [MS_Range:0] PCI_Master_Next_State =
              Master_Next_State (
                PCI_Master_State[MS_Range:0],
                external_pci_bus_available_critical,
                Request_FIFO_CONTAINS_ADDRESS,
                Master_Doing_Config_Reference,
                Request_FIFO_CONTAINS_DATA_TWO_MORE,
                Request_FIFO_CONTAINS_DATA_MORE,
                Request_FIFO_CONTAINS_DATA_LAST,
                Master_Abort_Detected,
                Master_Data_Latency_Disconnect, // | Master_Bus_Latency_Disconnect,  // NOTE: WORKING: test second term
                pci_trdy_in_critical,
                pci_stop_in_critical,
                Fast_Back_to_Back_Possible
              );

// NOTE: WORKING: rewrite state machine to have case ({pci_trdy_in, pci_stop_in})
//    right before the flops.  Make 4 functions from the 1 function above.

// Actual State Machine includes async reset
  reg    [MS_Range:0] PCI_Master_Prev_State;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      PCI_Master_State[MS_Range:0] <= PCI_MASTER_IDLE;
      PCI_Master_Prev_State[MS_Range:0] <= PCI_MASTER_IDLE;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      PCI_Master_State[MS_Range:0] <= PCI_Master_Next_State[MS_Range:0];
      PCI_Master_Prev_State[MS_Range:0] <= PCI_Master_State[MS_Range:0];
    end
    else
    begin
      PCI_Master_State[MS_Range:0] <= MS_X;
      PCI_Master_Prev_State[MS_Range:0] <= MS_X;
    end
  end

// Classify the Present State to make the terms below easier to understand.
  wire    Master_In_Idle_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_IDLE);

  wire    Master_In_Park_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_PARK);

  wire    Master_In_Step_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_STEP);

  wire    Master_In_Idle_Park_Step_State =
                      (Master_In_Idle_State == 1'b1)
                    | (Master_In_Park_State == 1'b1)
                    | (Master_In_Step_State == 1'b1);

  wire    Master_In_Addr_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR64);

  wire    Master_In_Park_Step_Addr_State =
                      (Master_In_Park_State == 1'b1)
                    | (Master_In_Step_State == 1'b1)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR64);

  wire    Master_In_No_IRDY_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_MORE_PENDING)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_LAST_PENDING);

  wire    Master_In_Data_More_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE);

  wire    Master_In_Data_Last_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_LAST)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE_TO_LAST);

  wire    Master_Transferring_Data_If_TRDY =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_LAST)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE_TO_LAST);

  wire    Master_Transferring_Read_Data_If_TRDY = ~Master_Retry_Write
                    & (   (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                        | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_LAST)
                        | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE_TO_LAST));

  wire    Master_In_Read_State =  ~Master_Retry_Write // NOTE: WORKING: Not Early enough?
                    &  (   (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR)
                         | (PCI_Master_State[MS_Range:0] == PCI_MASTER_MORE_PENDING)
                         | (PCI_Master_State[MS_Range:0] == PCI_MASTER_LAST_PENDING)
                         | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                         | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_LAST)
                         | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE_TO_LAST) );

  wire    Master_In_Nodata_Turn_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_NODATA_TURN);

  wire    Master_In_Stop_Turn_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_STOP_TURN);

  wire    Master_In_Last_Idle_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_LAST_IDLE);

// Retry info is encoded in the state machine activity.
// If the State Sequence goes IDLE/PARK, STEP, IDLE, then reuse the Address.
// If the State is STOP_TURN, either flush if Master Abort or Target Abort,
//   or reuse the Address + Data after Target Disconnect.
// If the State is NODATA_TURN, always reuse the Address + Data.
// If the State Sequence goes PCI_MASTER_DATA_MORE_TO_LAST, IDLE, reuse the Address.
// If the State is LAST_IDLE, either flush if Master Abort or Target Abort,
//   or reuse the Address + Data after Target Disconnect.  The flush
//   must not remove data from the FIFO if the data just issued was DATA_LAST.
// Increment Address if:  In DATA_MORE and ack to PENDING, MORE, LAST, NODATA_TURN,
//   or in DATA_MORE_TO_LAST and ack to IDLE
// In cases where just Address is available, wait for Data before going to ADDR
// In cases where Addr and Data are available, if data_more wait for data before
//   leaving more_pending (as usual)

// NOTE: WORKING: any way to keep AD bus from latching data when Target is using it?
// NOTE: WORKING: this would allow the always latch term to not be critical.

// Keep track of the stored Address and Data validity
// NOTE: These signals are delayed from when the data goes onto the bus
// NOTE: WORKING: These signals must go away when the data is comsumed, to not mess up the rest of the packet. 
  reg     Need_To_Retry_Address_But_No_Data, Need_To_Retry_Address_Plus_Data;
  reg     Need_To_Flush_FIFO, Need_To_Inc_Stored_Address;
  reg     Need_To_Delay_Next_Req;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Need_To_Retry_Address_But_No_Data <= 1'b0;
      Need_To_Retry_Address_Plus_Data <= 1'b0;
      Need_To_Flush_FIFO <= 1'b0;
      Need_To_Inc_Stored_Address <= 1'b0;
      Need_To_Delay_Next_Req <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      Need_To_Retry_Address_But_No_Data <=
                      (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_STEP)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_IDLE) )
                    | (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_DATA_MORE_TO_LAST)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_IDLE)
                    | (   (Need_To_Retry_Address_But_No_Data == 1'b1)
                        & (Master_In_No_IRDY_State == 1'b0)) );  // NOTE: WORKING

      Need_To_Retry_Address_Plus_Data <=
                      (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_STOP_TURN)
                        & (pci_trdy_in_prev == 1'b1)
                    | (   (Need_To_Retry_Address_Plus_Data == 1'b1)
                        & (Master_In_No_IRDY_State == 1'b0)) );  // NOTE: WORKING

      Need_To_Flush_FIFO <=
                      (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_STOP_TURN)
                        & (pci_trdy_in_prev == 1'b0) )
                    | (1'b0);  // NOTE: WORKING

// NOTE: WORKING: Need to flush data from FIFO.  The data might have come in and
//  been placed onto the bus (and sent to the Target).  Or the data might get there
//  late and not be available until after the Master Abort happens.
// In either case, need to flush until a Data Last is seen exiting the FIFO.
      Need_To_Inc_Stored_Address <=
                      (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_MORE_PENDING) )
                    | (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE) )
                    | (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_LAST) )
                    | (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_DATA_MORE)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_NODATA_TURN) )
                    | (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_DATA_MORE_TO_LAST)
                        & (PCI_Master_State[MS_Range:0] == PCI_MASTER_IDLE) );  // NOTE: WORKING
      Need_To_Delay_Next_Req = 1'b0;  // NOTE: WORKING: Need to include case of Step and no ACK
    end
    else
    begin
      Need_To_Retry_Address_But_No_Data <= 1'bX;
      Need_To_Retry_Address_Plus_Data <= 1'bX;
      Need_To_Flush_FIFO <= 1'bX;
      Need_To_Inc_Stored_Address <= 1'bX;
      Need_To_Delay_Next_Req <= 1'bX;
    end
  end

// Note: Want to DELAY after an event which needs an abort.  This will let other
//   people use the bus, and will let all my pipelines settle!
// Tell the Fifo Entry Classifier how to act upon the FIFO contents;
  assign  proceed_with_new_address_plus_new_data =
                 ~Need_To_Delay_Next_Req
               & ~Need_To_Retry_Address_But_No_Data
               & ~Need_To_Retry_Address_Plus_Data
               & ~Need_To_Flush_FIFO;
  assign  proceed_with_stored_address_plus_new_data =
                 ~Need_To_Delay_Next_Req
               &  Need_To_Retry_Address_But_No_Data;
  assign  proceed_with_stored_address_plus_stored_data =
                 ~Need_To_Delay_Next_Req
               &  Need_To_Retry_Address_Plus_Data;
  assign  inc_stored_address = Need_To_Inc_Stored_Address;

// Calculate several control signals used to direct data and control
// These signals depend on the present state of the PCI Master State
//   Machine and the LATCHED versions of DEVSEL, TRDY, STOP, PERR, SERR
// The un-latched versions can't be used, because they are too late.

// During Address Phase and First Data Phase, always update the PCI Bus.
// After those two clocks, the PCI bus will only update when IRDY and TRDY.

// Controls the unloading of the Request FIFO.  Only unload when previous data done.
  assign  Master_Consumes_Request_FIFO_Data_Unconditionally_Critical =
                  (   (Request_FIFO_CONTAINS_ADDRESS == 1'b1)  // Address
                    & (external_pci_bus_available_critical == 1'b1)  // Have bus  // NOTE: WORKING: REMOVE!
                    & (   (Master_In_Idle_State == 1'b1)
                        | (Master_In_Park_State == 1'b1)) )
                | (Master_In_Addr_State == 1'b1)  // First Data
//              | 1'b0;  // NOTE: WORKING  Need Fast Back-to-Back Address term
                | Master_Discards_Request_FIFO_Entry_After_Abort;

// This signal controls the actual PCI IO Pads, and results in data the next clock.
  assign  Master_Force_AD_to_Address_Data_Critical =  // drive outputs
                  (   (external_pci_bus_available_critical == 1'b1)  // Have bus  // NOTE: WORKING: REMOVE!
                    & (   (Master_In_Idle_State == 1'b1)
                        | (Master_In_Park_State == 1'b1)))
                | (Master_In_Addr_State == 1'b1);  // First Data
//              | 1'b0;  // NOTE: WORKING  Need Fast Back-to-Back Address term

// This signal controls the unloading of the Request FIFO in this module.
  assign  Master_Consumes_Request_FIFO_If_TRDY =
                  Master_Transferring_Data_If_TRDY
                | 1'b0;  // NOTE: WORKING  Might put fast back-to-back term here!

// This signal controls the actual PCI IO Pads, and results in data the next clock.
  assign  Master_Exposes_Data_On_TRDY = Master_Consumes_Request_FIFO_If_TRDY;  // drive outputs  // NOTE: WORKING  Only on READS!

// This signal tells the Target to grab data from the PCI bus this clock.
  assign  Master_Captures_Data_On_TRDY = Master_Consumes_Request_FIFO_If_TRDY;  // drive outputs  // NOTE: WORKING  Only on READS!

// Start the DEVSEL counter whenever an Address is sent out.
  assign  Master_Clear_Master_Abort_Counter =
                        (Master_In_Idle_Park_Step_State == 1'b1)
                      | (Master_In_Addr_State == 1'b1);  // NOTE: WORKING: fast back-to-back

// Start the Data Latency Counter whenever Address or IRDY & TRDY
  reg     Master_Transferring_Data_If_TRDY_prev;

  always @(posedge pci_clk)
  begin
    Master_Transferring_Data_If_TRDY_prev <= Master_Transferring_Data_If_TRDY;
  end

  assign  Master_Clear_Data_Latency_Counter =
                        (Master_In_Idle_Park_Step_State == 1'b1)
                      | (Master_In_Addr_State == 1'b1)
                      | (   (Master_Transferring_Data_If_TRDY_prev == 1'b1)
                          & pci_trdy_in_prev);

// Bus Latency Timer counts whenever GNT not asserted.
  assign  Master_Clear_Bus_Latency_Timer = 1'b0;  // NOTE: WORKING

// This signal muxes the Stored Address onto the PCI bus during retries.
  wire    Master_Select_Stored_Address =
                  (   proceed_with_stored_address_plus_new_data
                    | proceed_with_stored_address_plus_stored_data)
                & (Master_In_Idle_Park_Step_State == 1'b1);  // NOTE: WORKING add fast back-to-back

// This signal muxes the Stored Data onto the PCI bus during retries.
  wire    Master_Select_Stored_Data =
                        proceed_with_stored_address_plus_stored_data
                      & (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR);

  assign  Master_Mark_Status_Entry_Flushed = 1'b0;  // NOTE: WORKING
  assign  Master_Discards_Request_FIFO_Entry_After_Abort = 1'b0;  // NOTE: WORKING
  assign  Master_Got_Retry = 1'b0;  // NOTE WORKING

// NOTE: WORKING: this plays in to the idea that fast back-to-back does NOT
//   need to look at the FRAME and IRDY.  IT just lunges ahead, until it
//   sees the Bus Latency Timer time out.  Fast Back-to-Back therefore depends
//   on whether the timeout happens.
  assign  Fast_Back_to_Back_Possible = 1'b0;  // NOTE: WORKING
  assign  Master_Forced_Off_Bus_By_Target_Abort = 1'b0;  // NOTE: WORKING
  assign  Master_Forces_PERR = 1'b0;  // NOTE: WORKING

  assign  master_got_parity_error = 1'b0;  // NOTE: WORKING
  assign  master_caused_serr = 1'b0;  // NOTE: WORKING
  assign  master_caused_master_abort = 1'b0;  // NOTE: WORKING
  assign  master_got_target_abort = 1'b0;  // NOTE: WORKING
  assign  master_caused_parity_error = 1'b0;  // NOTE: WORKING
  assign  master_asked_to_retry = 1'b0;  // NOTE: WORKING

// Whenever the Master is told to get off the bus due to a Target Termination,
// it must remove it's Request for one clock when the bus goes idle and
// one other clock, either before or after the time the bus goes idle.
// See the PCI Local Bus Spec Revision 2.2 section 3.4.1 for details.
// Request whenever enabled, and an Address is available in the Master FIFO
// or a retried address is available.
// NOTE: WORKING: needs a Flop to make this Glitch-Free.  But no extra clocks?
  assign  pci_req_out_next = Request_FIFO_CONTAINS_ADDRESS
                           & (Master_In_Idle_Park_Step_State == 1'b1);

// PCI Request is tri-stated when Reset is asserted.
//   See the PCI Local Bus Spec Revision 2.2 section 2.2.4 for details.
  assign  pci_req_out_oe_comb = ~pci_reset_comb;

  assign  pci_master_ad_out_next[PCI_BUS_DATA_RANGE:0] =
                         Master_Select_Stored_Address
                      ?  Master_Retry_Address[PCI_BUS_DATA_RANGE:0]
                      : (Master_Select_Stored_Data
                      ?  Master_Retry_Data[PCI_BUS_DATA_RANGE:0]
                      :  pci_request_fifo_data_current[PCI_BUS_DATA_RANGE:0]);

  assign  pci_master_ad_out_oe_comb = PCI_Master_State[4]
                                    & (   Master_In_Park_Step_Addr_State
                                        | ~Master_In_Read_State);

  assign  pci_cbe_l_out_next[PCI_BUS_CBE_RANGE:0] =
                         Master_Select_Stored_Address
                      ?  Master_Retry_Command[PCI_BUS_CBE_RANGE:0]
                      : (Master_Select_Stored_Data
                      ?  Master_Retry_Data_Byte_Enables[PCI_BUS_CBE_RANGE:0]
                      :  pci_request_fifo_cbe_current[PCI_BUS_CBE_RANGE:0]);

  assign  pci_cbe_out_oe_comb = PCI_Master_State[4];

  assign  pci_frame_out_next = PCI_Master_Next_State[3];
  assign  pci_frame_out_oe_comb = PCI_Master_State[3] | PCI_Master_Prev_State[3];

  assign  pci_irdy_out_next = PCI_Master_Next_State[2];
  assign  pci_irdy_out_oe_comb = PCI_Master_State[2] | PCI_Master_Prev_State[2];

// synopsys translate_off
// Check that the Request FIFO is getting entries in the allowed order
//   Address->Data->Data_Last.  Anything else is an error.
//   NOTE: ONLY CHECKED IN SIMULATION.  In the real circuit, the FIFO
//         FILLER is responsible for only writing valid stuff into the FIFO.
  parameter PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS = 1'b0;
  parameter PCI_REQUEST_FIFO_WAITING_FOR_LAST    = 1'b1;
  reg     request_fifo_state;  // tracks no_address, address, data, data_last;
  reg     master_request_fifo_error;  // Notices FIFO error, or FIFO Contents out of sequence

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      master_request_fifo_error <= 1'b0;
      request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      if (prefetching_request_fifo_data == 1'b1)
      begin
        if (request_fifo_state == PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS)
        begin
          if (  (pci_request_fifo_type_current[2:0] == PCI_HOST_REQUEST_SPARE)
              | (pci_request_fifo_type_current[2:0] == PCI_HOST_REQUEST_W_DATA_RW_MASK)
              | (pci_request_fifo_type_current[2:0]
                                == PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
              | (pci_request_fifo_type_current[2:0]
                                == PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR) 
              | (pci_request_fifo_type_current[2:0]
                                == PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) )
          begin
            master_request_fifo_error <= 1'b1;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else if (pci_request_fifo_type_current[2:0]
                                == PCI_HOST_REQUEST_INSERT_WRITE_FENCE)
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
          if (  (pci_request_fifo_type_current[2:0] == PCI_HOST_REQUEST_SPARE)
              | (pci_request_fifo_type_current[2:0] == PCI_HOST_REQUEST_ADDRESS_COMMAND)
              | (pci_request_fifo_type_current[2:0]
                                == PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR)
              | (pci_request_fifo_type_current[2:0]
                                == PCI_HOST_REQUEST_INSERT_WRITE_FENCE) )
          begin
            master_request_fifo_error <= 1'b1;
            request_fifo_state <= PCI_REQUEST_FIFO_WAITING_FOR_ADDRESS;
          end
          else if (  (pci_request_fifo_type_current[2:0]
                         == PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                   | (pci_request_fifo_type_current[2:0]
                         == PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) )
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
      else  // (prefetching_request_fifo_data == 1'b0)
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
      $display ("*** %m PCI Master Request Fifo Unload Error at time %t", $time);
    end
  end
// synopsys translate_on

// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
// Look inside the master module and try to call out transition names.
  reg     prev_master_abort, prev_fifo_contains_address, prev_fifo_contains_data_more;
  reg     prev_fifo_contains_data_last, prev_timeout_forces_disconnect;
  reg     prev_back_to_back_possible, prev_doing_config_reference;
  reg     prev_bus_available, prev_config_reference;
  always @(posedge pci_clk)
  begin
    prev_bus_available <= external_pci_bus_available_critical;
    prev_master_abort <= Master_Abort_Detected;
    prev_fifo_contains_address <= Request_FIFO_CONTAINS_ADDRESS;
    prev_config_reference <= Master_Doing_Config_Reference;
    prev_fifo_contains_data_more <= Request_FIFO_CONTAINS_DATA_MORE;
    prev_fifo_contains_data_last <= Request_FIFO_CONTAINS_DATA_LAST;
    prev_timeout_forces_disconnect <= Master_Data_Latency_Disconnect;
    prev_back_to_back_possible <= Fast_Back_to_Back_Possible;
    prev_doing_config_reference <= Master_Doing_Config_Reference;
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b0) )
      $display ("transition 1 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b1) )
      $display ("transition 2 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b0) )
      $display ("transition 3 seen");
//    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
//         & (PCI_Master_State[4:0] == PCI_MASTER_IDLE) )
//      $display ("transition 4 seen");

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_fifo_contains_address == 1'b0) )
      $display ("transition 5 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b1) )
      $display ("transition 6 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b0) )
      $display ("transition 7 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (PCI_Master_State[4:0] == PCI_MASTER_IDLE) )
      $display ("transition 8 seen");

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_STEP)
         & (PCI_Master_State[4:0] == PCI_MASTER_IDLE) )
      $display ("transition 9 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_STEP)
         & (PCI_Master_State[4:0] == PCI_MASTER_ADDR) )
      $display ("transition 10 seen");

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_ADDR)
         & (PCI_Master_State[4:0] == PCI_MASTER_LAST_PENDING) )
      $display ("transition 11 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_ADDR)
         & (PCI_Master_State[4:0] == PCI_MASTER_MORE_PENDING) )
      $display ("transition 12 seen");

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b1) )
      $display ("transition 15 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 16 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 17 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 18 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 19 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 20 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 21 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_timeout_forces_disconnect == 1'b1)
         & (prev_master_abort == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 22 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 23 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 24 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 25 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 26 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (prev_master_abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 27 seen");

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b1) )
      $display ("transition 28 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 29 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 30 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 31 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 32 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 33 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 34 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 35 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 36 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 37 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 38 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 39 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 40 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b1)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 41 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b1)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 42 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b1)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 43 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_data_more == 1'b1)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 44 seen");


    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b1) )
      $display ("transition 45 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 46 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 47 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 48 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 49 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 50 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 51 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 52 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (prev_master_abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 53 seen");

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_TO_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      $display ("transition 54 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_TO_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      $display ("transition 55 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_TO_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      $display ("transition 56 seen");
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_TO_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      $display ("transition 57 seen");
  end
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
endmodule

