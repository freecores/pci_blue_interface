//===========================================================================
// $Id: pci_blue_master.v,v 1.33 2001-08-11 10:13:11 bbeaver Exp $
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
  This_Chip_Driving_IRDY,
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
  input   This_Chip_Driving_IRDY;
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
  wire    proceed_with_new_data;
  wire    inc_stored_address;
  wire    Finished_With_FIFO_Flush;
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
                                      & ~master_request_full;   // transfered to PCI bus

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
//   been UNLOADED from the Request FIFO onto the PCI bus.  This indicates
//   that it has been driven  to the external bus.
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
//   been UNLOADED from the Request FIFO onto the PCI bus.  This indicates
//   that it has been driven  to the external bus.
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
                      | (Master_Data_Latency_Counter[2:0] >= 3'h5);
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
      if (   (Master_Data_Latency_Disconnect_Reg == 1'b0)
           & (Master_Data_Latency_Counter[2:0] >= 3'h5)
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
//   removed.  As soon as Frame is adderted, the counter starts.
// The Master get to keep the bus until the counter counts to it's maximum value
//   AND Gnt is removed.  Don't time out if GNT is not removed, or if the counter
//   has not counted to Max.  The duration of a transfer, therefore, is the
//   Latency Counter plus 1.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.4 for details.
// NOTE: I assume that fast back-to-back transfers are not allowed when GNT is
//   removed, but the book doesn't say that.
  reg    [7:0] Master_Bus_Latency_Counter;
  reg     Master_Bus_Latency_Disconnect_Reg;

  always @(posedge pci_clk)
  begin
    if (Master_Clear_Bus_Latency_Timer == 1'b1)
    begin
      Master_Bus_Latency_Counter[7:0] <= 8'h02;
      Master_Bus_Latency_Disconnect_Reg <= 1'b0;
    end
    else if (Master_Clear_Bus_Latency_Timer == 1'b0)
    begin
      Master_Bus_Latency_Counter[7:0] <= Master_Bus_Latency_Counter[7:0] + 8'h01;
      Master_Bus_Latency_Disconnect_Reg <= Master_Bus_Latency_Disconnect_Reg
                      | (Master_Bus_Latency_Counter[7:0]
                                 >= master_latency_value[7:0]);
// synopsys translate_off
`ifdef VERBOSE_MASTER_DEVICE
      if (   (Master_Bus_Latency_Disconnect_Reg == 1'b0)
           & (Master_Bus_Latency_Counter[7:0]
                                 >= master_latency_value[7:0]))
        $display ("%m PCI Master Bus Latency Disconnect detected, at time %t", $time);
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
    end
// synopsys translate_off
    else
    begin
      Master_Bus_Latency_Counter[7:0] <= 8'hXX;
      Master_Bus_Latency_Disconnect_Reg <= 1'bX;
    end
// synopsys translate_on
  end

  wire    Master_Bus_Latency_Disconnect = Master_Bus_Latency_Disconnect_Reg
                                        & ~pci_gnt_in_critical;

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

  wire    Request_FIFO_CONTAINS_ADDRESS =
               master_enable  // only start (or retry) a reference if enabled
             & master_to_target_status_loadable
             & master_to_target_status_two_words_free  // room for status to Target
             & (   (   proceed_with_new_address_plus_new_data
                     & request_fifo_two_words_available_meta
                     & (   (pci_request_fifo_type_current[2:0] ==
                                PCI_HOST_REQUEST_ADDRESS_COMMAND)  // Not if Housekeeping
                         | (pci_request_fifo_type_current[2:0] ==
                                PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR)
                   )  // new address plus new data
                 | (   proceed_with_stored_address_plus_new_data
                     & request_fifo_data_available_meta)  // stored address plus data
                 | proceed_with_stored_address_plus_stored_data) );  // both stored

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
                          | proceed_with_stored_address_plus_new_data
                          | proceed_with_new_data )
                      ? pci_request_fifo_type_current[2:0]
                      : Master_Retry_Data_Type[2:0];

  wire    Request_FIFO_CONTAINS_DATA_MORE =
               master_to_target_status_loadable  // room for status to Target
             & (   (   (   proceed_with_new_address_plus_new_data
                         | proceed_with_stored_address_plus_new_data
                         | proceed_with_new_data )
                     & request_fifo_data_available_meta )
                 | proceed_with_stored_address_plus_stored_data )
             & (   (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK)
                 | (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR));

  wire    Request_FIFO_CONTAINS_DATA_LAST =
               master_to_target_status_loadable  // room for status to Target
             & (   (   (   proceed_with_new_address_plus_new_data
                         | proceed_with_stored_address_plus_new_data
                         | proceed_with_new_data )
                     & request_fifo_data_available_meta )
                 | proceed_with_stored_address_plus_stored_data )
             & (   (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                 | (Next_Data_Type[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR));

// By the time this gets to DATA_MORE state, it has already exposed
//   the data being stored for retries.  All that matters is the FIFO.
  wire    Request_FIFO_CONTAINS_DATA_TWO_MORE =  // used in DATA_MORE
               master_to_target_status_loadable
             & master_to_target_status_two_words_free  // room for status to Target
             & request_fifo_two_words_available_meta  // data in FIFO
             & (   (pci_request_fifo_type_current[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK)
                 | (pci_request_fifo_type_current[2:0] ==
                                PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR));

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
// The Master is in one of 3 states when transfering data:
// 1) Waiting,
// 2) Transfering data with more to come,
// 3) Transfering the last Data item.
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

  parameter PCI_MASTER_DATA_LAST         = 5'b1_01_10;  // 16 Master Transfers Last Data
  parameter PCI_MASTER_DATA_MORE_AS_LAST = 5'b1_01_11;  // 17 Master Transfers Regular Data as Last

  parameter PCI_MASTER_EARLY_LAST_TURN   = 5'b1_01_00;  // 14 Target Transfers More Data as Last, then No Data
  parameter PCI_MASTER_STOP_TURN         = 5'b1_01_01;  // 15 Target Abort or Disconnect makes Turn Around

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
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;          // 17, 58
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;       // 18
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 19
            `NO_DEFAULT;
            endcase
          end
          else if (Timeout_Forces_Disconnect == 1'b1)  // NOTE: shortcut; even if no data
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 20
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;          // 21, 59
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 22
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 23
            `NO_DEFAULT;
            endcase
          end
          else if (   (Timeout_Forces_Disconnect == 1'b0)
                    & (   (FIFO_CONTAINS_DATA_MORE == 1'b1)
                        | (FIFO_CONTAINS_DATA_LAST == 1'b1)) )
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;          // 24
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;          // 25, 60
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;          // 26
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 27
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
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;     // 30, 61
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_MORE_PENDING;  // 31
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_EARLY_LAST_TURN; // 32
            `NO_DEFAULT;
            endcase
          end
          else if (FIFO_CONTAINS_DATA_LAST == 1'b1)
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 33
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;    // 34, 62
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_LAST;    // 35
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_EARLY_LAST_TURN; // 36
            `NO_DEFAULT;
            endcase
          end
          else if (   (FIFO_CONTAINS_DATA_LAST == 1'b0)
                    & (Timeout_Forces_Disconnect == 1'b1) )  // NOTE: shortcut; even if no data
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 37
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;    // 38, 63
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 39 bug?
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_EARLY_LAST_TURN; // 40
            `NO_DEFAULT;
            endcase
          end
          else if (   (FIFO_CONTAINS_DATA_LAST == 1'b0)
                    & (Timeout_Forces_Disconnect == 1'b0)
                    & (FIFO_CONTAINS_DATA_TWO_MORE == 1'b1) )
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 41
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_STOP_TURN;    // 42, 64
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE;    // 43
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_EARLY_LAST_TURN; // 44
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
// Enter EARLY_LAST_TURN State when Master says More, but Target says Last
// The present data is transfered, the next data is not.  Drive IRDY, CBE, Data if write
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_EARLY_LAST_TURN:
        begin
          Master_Next_State[MS_Range:0] = PCI_MASTER_IDLE;  // Covered
        end
// Enter STOP_TURN when Master asserting FRAME and either IRDY or not IRDY,
//   and either a Master Abort happens, or a Target Abort happens, or a
//   Target Retry with no data transfered happens.  Drive IRDY, CBE, Data if write
// The waiting data is not transfered.
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
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 47, 65
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
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 51, 66
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
// Enter MORE_AS_LAST State for 1 of several reasons:
// 1) Master waiting for second Data to become available, and Target says early Last.
//      Make the data in escrow into an early Last.
// 2) Master waiting for Target to accept More Data, and bus timeout occurs,
//      and Target says More.  Make the NEW data into an early Last.
// The data sent is sent as a Last Data, even if it is a More Data.
// NOTE: in case case of timeout, the MORE_AS_LAST might terminate with a STOP!
// NOTE: No specific term to get to Bus Park.  It is not necessary to go directly
//    to a parked condition.  Get to park by going through IDLE.  See the PCI
//    Local Bus Spec Revision 2.2 section 3.4.3 for details.
      PCI_MASTER_DATA_MORE_AS_LAST:
        begin
          begin
            case ({trdy_in, stop_in})  // synopsys parallel_case
            TARGET_IDLE:      Master_Next_State[MS_Range:0] = PCI_MASTER_DATA_MORE_AS_LAST;  // 54
            TARGET_TAR:       Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 55, 67
            TARGET_DATA_MORE: Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 56
            TARGET_DATA_LAST: Master_Next_State[MS_Range:0] = PCI_MASTER_LAST_IDLE;  // 57
            `NO_DEFAULT;
            endcase
          end
        end
// Enter LAST_IDLE when Master asserting IRDY and not FRAME,
//   and either a Master Abort happens, or a Target Abort happens, or a
//   Target Retry with no data transfered happens, or a target transfer finishes.
// This state is the same as STOP_TURN, except IRDY, CBE, and Data, are not driven.
// The waiting data is not transfered.
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
// NOTE: Very Subtle point.  The PCI Master may NOT look at the value
//   of signals it drove itself the previous clock.  The driver of a PCI bus
//   receives the value it drove later than all other devices.  See the PCI
//   Local Bus Spec Revision 2.2 section 3.10 item 9 for details.
//   FRAME isn't a problem, because it is driven 1 clock before IRDY.
//   Therefore hold off for 1 clock after this chip's target is done with
//   the PC bus.
// This will mean that this master is 1 clock slower than it could be
//   in the case when this chip did a bus master transfer on the bus,
//   then then tried to do an immediate (but non-back-to-back) Master transfer.
// This might happen when there are several masters all on-chip, but not
//   sharing a single PCI interface.
  wire    external_pci_bus_available_critical = pci_gnt_in_critical
                        & ~pci_frame_in_critical & ~pci_irdy_in_critical
                        & ~This_Chip_Driving_IRDY;

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
                Master_Data_Latency_Disconnect | Master_Bus_Latency_Disconnect,
                pci_trdy_in_critical,
                pci_stop_in_critical,
                Fast_Back_to_Back_Possible
              );

// NOTE: WORKING: rewrite state machine to have case ({pci_trdy_in, pci_stop_in})
//    right before the flops.  Make 4 functions from the 1 function above.

// Actual State Machine includes async reset
  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
      PCI_Master_State[MS_Range:0] <= PCI_MASTER_IDLE;
    else if (pci_reset_comb == 1'b0)
      PCI_Master_State[MS_Range:0] <= PCI_Master_Next_State[MS_Range:0];
    else
      PCI_Master_State[MS_Range:0] <= MS_X;
  end

// Make delayed version, used for active release of FRAME and IRDY.
  reg    [MS_Range:0] PCI_Master_Prev_State;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
      PCI_Master_Prev_State[MS_Range:0] <= PCI_MASTER_IDLE;
    else if (pci_reset_comb == 1'b0)
      PCI_Master_Prev_State[MS_Range:0] <= PCI_Master_State[MS_Range:0];
    else
      PCI_Master_Prev_State[MS_Range:0] <= MS_X;
  end

// Classify the Present State to make the terms below easier to understand.
  wire    Master_In_Idle_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_IDLE);

  wire    Master_In_Park_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_PARK);

  wire    Master_In_Step_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_STEP);

  wire    Master_In_Addr_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR64);

// NOTE: Becomes ADDR64 when this learns how to send 64-bit addresses, AND
//       the particular reference IS a 64-bit Address reference,
  wire    Master_Sending_First_Data =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_ADDR);

  wire    Master_In_No_IRDY_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_MORE_PENDING)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_LAST_PENDING);

  wire    Master_In_Data_More_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE);

  wire    Master_In_Early_Last_Turn_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_EARLY_LAST_TURN);

  wire    Master_In_Stop_Turn_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_STOP_TURN);

  wire    Master_In_Data_Last_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_LAST)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_DATA_MORE_AS_LAST);

  wire    Master_In_Stop_Turn_Last_Idle_State =
                      (PCI_Master_State[MS_Range:0] == PCI_MASTER_STOP_TURN)
                    | (PCI_Master_State[MS_Range:0] == PCI_MASTER_LAST_IDLE);

// combined decodes
  wire    Master_In_Idle_Park_Step_State =
                      (Master_In_Idle_State == 1'b1)
                    | (Master_In_Park_State == 1'b1)
                    | (Master_In_Step_State == 1'b1);

  wire    Master_In_Park_Step_Addr_State =
                      (Master_In_Park_State == 1'b1)
                    | (Master_In_Step_State == 1'b1)
                    | (Master_In_Addr_State == 1'b1);

  wire    Master_Trying_To_Transfer_Data  =
                      (Master_In_No_IRDY_State == 1'b1)
                    | (Master_In_Data_More_State == 1'b1)
                    | (Master_In_Data_Last_State == 1'b1);

  wire    Master_In_Last_Data_Phase =
                      (Master_In_Data_Last_State == 1'b1)
                    | (Master_In_Stop_Turn_State == 1'b1)
                    | (Master_In_Early_Last_Turn_State == 1'b1);

  wire    Master_Transfering_Data_If_TRDY =
                      (Master_In_Data_More_State == 1'b1)
                    | (Master_In_Data_Last_State == 1'b1);

  wire    Master_Transfering_Read_Data_If_TRDY =
                      ~Master_Retry_Write
                    & (   (Master_In_Data_More_State == 1'b1)
                        | (Master_In_Data_Last_State == 1'b1) );

  wire    Master_In_Read_State =
                       ~Master_Retry_Write
                    &  (   (Master_In_Addr_State == 1'b1)
                         | (Master_In_No_IRDY_State == 1'b1)
                         | (Master_In_Data_More_State == 1'b1)
                         | (Master_In_Data_Last_State == 1'b1)
                         | (Master_In_Early_Last_Turn_State == 1'b1)
                         | (Master_In_Stop_Turn_State == 1'b1) );

  wire    Master_In_No_Data_Turn_State =
                      (Master_In_Stop_Turn_State == 1'b1)
                    | (Master_In_Early_Last_Turn_State == 1'b1);

  wire    Master_Asserting_Frame =
                      (Master_In_Addr_State == 1'b1)
                    | (Master_In_No_IRDY_State == 1'b1)
                    | (Master_In_Data_More_State == 1'b1);

  wire    Master_Asserting_IRDY =
                      (Master_In_Data_More_State == 1'b1)
                    | (Master_In_No_Data_Turn_State == 1'b1)
                    | (Master_In_Data_Last_State == 1'b1);

// Retry info is encoded in the state machine activity.
//
// in state step: retry nodata if goes back to idle
// in state more_pending:  Flush if Master Abort (stop_turn), retry data or flush if goes to stop_turn
// in state data_more:     Flush if Master Abort (stop_turn), retry data or flush if goes to stop_turn
// in state data_more:     retry data if taken as last, (cause pipeline moves new data into place)
//                         indicated by transfer to early_last_turn
// in state data_last:     Flush if Master Abort (last_idle), retry data or flush if goes to last_idle
// in state more_to_last:  retry data or flush if goes to last_idle because of termination
// in state more_to_last:  retry nodata if goes to last_idle because of good transfer
//
// Taken another way,
// if stop_turn or last_idle, and Master_Abort, flush
// if stop_turn or last_idle, and not Master_Abort, and Target Abort, flush
// if stop_turn or last_idle, and not Master_Abort, and not Target Abort,
//   and no data transfered, retry data
// if early_last, retry without data
// if last_idle and data transfered, retry without data

// Keep track of the stored Address and Data validity
  reg     Need_To_Retry_Address_But_No_Data, Need_To_Retry_Address_Plus_Data;
  reg     Delayed_Need_To_Retry_Address_But_No_Data;
  reg     Delayed_Need_To_Retry_Address_Plus_Data;
  reg     Need_To_Flush_FIFO, Need_To_Inc_Stored_Address;
  reg     In_Middle_Of_Reference;
  reg     Prev_Master_Abort;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Prev_Master_Abort <= 1'b0;
      In_Middle_Of_Reference <= 1'b0;
      Need_To_Retry_Address_But_No_Data <= 1'b0;
      Need_To_Retry_Address_Plus_Data <= 1'b0;
      Need_To_Flush_FIFO <= 1'b0;
      Need_To_Inc_Stored_Address <= 1'b0;
      Delayed_Need_To_Retry_Address_But_No_Data <= 1'b0;
      Delayed_Need_To_Retry_Address_Plus_Data <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      Prev_Master_Abort <= Master_Abort_Detected;

      In_Middle_Of_Reference <= (Master_Sending_First_Data == 1'b1)
                              | (Master_Trying_To_Transfer_Data == 1'b1);

      Need_To_Flush_FIFO <=  // if master or target abort
                      (   (Master_In_Stop_Turn_Last_Idle_State == 1'b1)
                        & (   (Prev_Master_Abort == 1'b1)  // master abort
                            | (   (pci_devsel_in_prev == 1'b0)
                                & (pci_trdy_in_prev == 1'b0)
                                & (pci_stop_in_prev == 1'b1) )  // target abort
                          )
                      )
                    | (   (Need_To_Flush_FIFO == 1'b1)
                        & (Finished_With_FIFO_Flush == 1'b0) );

      Need_To_Retry_Address_Plus_Data <=  // data not accepted, but more data available
                      (   (Master_In_Stop_Turn_Last_Idle_State == 1'b1)
                        & (Prev_Master_Abort == 1'b0)
                        & (   (pci_devsel_in_prev == 1'b1)
                            & (pci_trdy_in_prev == 1'b0)
                            & (pci_stop_in_prev == 1'b1) )  // no transfer and stop
                      )
                    | (Master_In_Early_Last_Turn_State == 1'b1)
                    | (   (Need_To_Retry_Address_Plus_Data == 1'b1)
                        & (Master_In_No_IRDY_State == 1'b0) );  // till granted again

      Need_To_Retry_Address_But_No_Data <=  // data accepted, but more data available
                      (   (Master_In_Stop_Turn_Last_Idle_State == 1'b1)
                        & (Prev_Master_Abort == 1'b0)
                        & (   (pci_devsel_in_prev == 1'b1)
                            & (pci_trdy_in_prev == 1'b1) )  // transfer with or without stop
                      )
                    | (   (PCI_Master_Prev_State[MS_Range:0] == PCI_MASTER_STEP)
                        & (Master_In_Idle_State == 1'b1)
                      )
                    | (   (Need_To_Retry_Address_But_No_Data == 1'b1)
                        & (Master_In_No_IRDY_State == 1'b0) );  // till granted again

      Need_To_Inc_Stored_Address <=  // what happened when exiting transfer state
                      (   (PCI_Master_Prev_State[MS_Range:0] ==
                                                 PCI_MASTER_DATA_MORE)
                        | (PCI_Master_Prev_State[MS_Range:0] ==
                                                 PCI_MASTER_DATA_LAST)
                        | (PCI_Master_Prev_State[MS_Range:0] ==
                                                 PCI_MASTER_DATA_MORE_AS_LAST) )
                    & (pci_trdy_in_prev == 1'b1);

      Delayed_Need_To_Retry_Address_But_No_Data <= Need_To_Retry_Address_But_No_Data;
      Delayed_Need_To_Retry_Address_Plus_Data <= Need_To_Retry_Address_Plus_Data;
    end
    else
    begin
      Prev_Master_Abort <= 1'bX;
      In_Middle_Of_Reference <= 1'bX;
      Need_To_Retry_Address_But_No_Data <= 1'bX;
      Need_To_Retry_Address_Plus_Data <= 1'bX;
      Need_To_Flush_FIFO <= 1'bX;
      Need_To_Inc_Stored_Address <= 1'bX;
      Delayed_Need_To_Retry_Address_But_No_Data <= 1'bX;
      Delayed_Need_To_Retry_Address_Plus_Data <= 1'bX;
    end
  end

// Tell the Fifo Entry Classifier how to act upon the FIFO contents;
  assign  proceed_with_new_address_plus_new_data =
                 ~In_Middle_Of_Reference
               & ~Need_To_Retry_Address_But_No_Data
               & ~Need_To_Retry_Address_Plus_Data
               & ~Need_To_Flush_FIFO;
  assign  proceed_with_stored_address_plus_new_data =
                 ~In_Middle_Of_Reference
               &  Need_To_Retry_Address_But_No_Data
               &  Delayed_Need_To_Retry_Address_But_No_Data
               & ~Need_To_Flush_FIFO;
  assign  proceed_with_stored_address_plus_stored_data =
                 ~In_Middle_Of_Reference
               &  Need_To_Retry_Address_Plus_Data
               &  Delayed_Need_To_Retry_Address_Plus_Data
               & ~Need_To_Flush_FIFO;
  assign  proceed_with_new_data = In_Middle_Of_Reference;  // stop bypassing data
  assign  inc_stored_address = Need_To_Inc_Stored_Address;


wire working = pci_stop_in_prev;  // ***

  assign  Finished_With_FIFO_Flush = 1'b0;  // NOTE: WORKING: Make FLUSH state machine


// NOTE: TOADS: first, need to make retries and flushes to work, plus re-steps.
// NOTE: TOADS: second, need to work on NOTE: WORKING: assigns
// NOTE: TOADS: third, need to rewrite state machine into 4 based on TRDY, STOP, plus 2 based on Bus Available

// NOTE: WORKING: any way to keep AD bus from latching data when Target is using it?
// NOTE: WORKING: this would allow the always latch term to not be critical.

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
                        | (Master_In_Park_State == 1'b1) )
                    & (proceed_with_new_address_plus_new_data == 1'b1)
                  )
                | (   (Master_In_Addr_State == 1'b1)  // First Data
                    & (   (proceed_with_new_address_plus_new_data == 1'b1)
                        | (proceed_with_stored_address_plus_new_data == 1'b1) )
                  )
//              | 1'b0;  // NOTE: WORKING:  Need Fast Back-to-Back Address term
                | Master_Discards_Request_FIFO_Entry_After_Abort;

// This signal controls the actual PCI IO Pads, and results in data the next clock.
  assign  Master_Force_AD_to_Address_Data_Critical =  // drive outputs
                  (   (external_pci_bus_available_critical == 1'b1)  // Have bus  // NOTE: WORKING: REMOVE!
                    & (   (Master_In_Idle_State == 1'b1)
                        | (Master_In_Park_State == 1'b1)))
                | (Master_In_Addr_State == 1'b1);  // First Data
//              | 1'b0;  // NOTE: WORKING:  Need Fast Back-to-Back Address term

// This signal controls the unloading of the Request FIFO in this module.
  assign  Master_Consumes_Request_FIFO_If_TRDY = Master_In_Data_More_State;

// This signal controls the actual PCI IO Pads, and results in data the next clock.
  assign  Master_Exposes_Data_On_TRDY = Master_Consumes_Request_FIFO_If_TRDY;  // drive outputs  // NOTE: WORKING:  Only on READS!

// This signal tells the Target to grab data from the PCI bus this clock.
  assign  Master_Captures_Data_On_TRDY = Master_Consumes_Request_FIFO_If_TRDY;  // drive outputs  // NOTE: WORKING:  Only on READS!

// Start the Master Abort counter looking for DEVSEL whenever an Address is sent out.
  assign  Master_Clear_Master_Abort_Counter =
                        (Master_In_Idle_Park_Step_State == 1'b1)
                      | (Master_In_Addr_State == 1'b1);

// Start the Data Latency Counter whenever Address or IRDY & TRDY
  reg     Master_Transfering_Data_If_TRDY_prev;

  always @(posedge pci_clk)
  begin
    Master_Transfering_Data_If_TRDY_prev <= Master_Transfering_Data_If_TRDY;
  end

// Data Latency Timer counts whenever Master waiting for more Master Data.
  assign  Master_Clear_Data_Latency_Counter = ~Master_In_No_IRDY_State;

// Bus Latency Timer counts whenever GNT not asserted.
  assign  Master_Clear_Bus_Latency_Timer = ~Master_Asserting_Frame;

// This signal muxes the Stored Address onto the PCI bus during retries.
  wire    Master_Select_Stored_Address =
                  (   proceed_with_stored_address_plus_new_data
                    | proceed_with_stored_address_plus_stored_data)
                & (Master_In_Idle_Park_Step_State == 1'b1);

// This signal muxes the Stored Data onto the PCI bus during retries.
  wire    Master_Select_Stored_Data =
                        proceed_with_stored_address_plus_stored_data
                      & (Master_Sending_First_Data == 1'b1);



  assign  Master_Mark_Status_Entry_Flushed = 1'b0;  // NOTE: WORKING:
  assign  Master_Discards_Request_FIFO_Entry_After_Abort = 1'b0;  // NOTE: WORKING:
  assign  Master_Got_Retry = 1'b0;  // NOTE: WORKING:

// NOTE: WORKING: this plays in to the idea that fast back-to-back does NOT
//   need to look at the FRAME and IRDY.  IT just lunges ahead, until it
//   sees the Bus Latency Timer time out.  Fast Back-to-Back therefore depends
//   on whether the timeout happens.
  assign  Fast_Back_to_Back_Possible = 1'b0;  // NOTE: WORKING:
  assign  Master_Forced_Off_Bus_By_Target_Abort = 1'b0;  // NOTE: WORKING:
  assign  Master_Forces_PERR = 1'b0;  // NOTE: WORKING:

  assign  master_got_parity_error = 1'b0;  // NOTE: WORKING:
  assign  master_caused_serr = 1'b0;  // NOTE: WORKING:
  assign  master_caused_master_abort = 1'b0;  // NOTE: WORKING:
  assign  master_got_target_abort = 1'b0;  // NOTE: WORKING:
  assign  master_caused_parity_error = 1'b0;  // NOTE: WORKING:
  assign  master_asked_to_retry = 1'b0;  // NOTE: WORKING:

// Whenever the Master is told to get off the bus due to a Target Termination,
// it must remove it's Request for one clock when the bus goes idle and
// one other clock, either before or after the time the bus goes idle.
// See the PCI Local Bus Spec Revision 2.2 section 3.4.1 for details.
// Request whenever enabled, and an Address is available in the Master FIFO
// or a retried address is available.
  assign  pci_req_out_next = (Request_FIFO_CONTAINS_ADDRESS  == 1'b1)
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
  assign  pci_frame_out_oe_comb = PCI_Master_State[3] | PCI_Master_Prev_State[3];  // NOTE: GLITCH?

  assign  pci_irdy_out_next = PCI_Master_Next_State[2];
  assign  pci_irdy_out_oe_comb = PCI_Master_State[2] | PCI_Master_Prev_State[2];  // NOTE: GLITCH?

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
  reg    [67:1] transitions_seen;

task initialize_transition_table;
  integer i;
  begin
    for (i = 1; i <= 67; i = i + 1)
    begin
      transitions_seen[i] = 1'b0;
    end
    transitions_seen[4] = 1'b1;
    transitions_seen[13] = 1'b1;
    transitions_seen[14] = 1'b1;
  end
endtask

task call_out_transition;
  input i;
  integer i;
  begin
    if ((i >= 1) & (i <= 67))
    begin
      $display ("transition %d seen at %t", i, $time);
      transitions_seen[i] = 1'b1;
    end
    else
    begin
      $display ("*** bogus transition %d seen at %t", i, $time);
    end
  end
endtask

task report_missing_transitions;
  integer i;
  begin
    for (i = 1; i <= 67; i = i + 1)
    begin
      if (transitions_seen[i] == 1'b0)
        $display ("transition %d not seen", i);
    end
  end
endtask

  initial initialize_transition_table;

  reg     prev_fifo_contains_address;
  reg     prev_fifo_contains_data_more, prev_fifo_contains_data_two_more;
  reg     prev_fifo_contains_data_last, prev_timeout_forces_disconnect;
  reg     prev_back_to_back_possible, prev_doing_config_reference;
  reg     prev_bus_available, prev_config_reference;
  always @(posedge pci_clk)
  begin
    prev_bus_available <= external_pci_bus_available_critical;
    prev_fifo_contains_address <= Request_FIFO_CONTAINS_ADDRESS;
    prev_config_reference <= Master_Doing_Config_Reference;
    prev_fifo_contains_data_more <= Request_FIFO_CONTAINS_DATA_MORE;
    prev_fifo_contains_data_two_more <= Request_FIFO_CONTAINS_DATA_TWO_MORE;
    prev_fifo_contains_data_last <= Request_FIFO_CONTAINS_DATA_LAST;
    prev_timeout_forces_disconnect <= Master_Data_Latency_Disconnect
                                    | Master_Bus_Latency_Disconnect;
    prev_back_to_back_possible <= Fast_Back_to_Back_Possible;
    prev_doing_config_reference <= Master_Doing_Config_Reference;
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b0) )
      call_out_transition (1);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b1) )
      call_out_transition (2);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b0) )
      call_out_transition (3);
//    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_IDLE)
//         & (PCI_Master_State[4:0] == PCI_MASTER_IDLE) )
//      call_out_transition (4);

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b0) )
      call_out_transition (5);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b1) )
      call_out_transition (6);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_config_reference == 1'b0) )
      call_out_transition (7);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_PARK)
         & (prev_bus_available == 1'b0) )
      call_out_transition (8);

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_STEP)
         & (prev_bus_available == 1'b1) )
      call_out_transition (9);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_STEP)
         & (prev_bus_available == 1'b0) )
      call_out_transition (10);

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_ADDR)
         & (prev_fifo_contains_data_last == 1'b1) )
      call_out_transition (11);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_ADDR)
         & (prev_fifo_contains_data_last == 1'b0) )
      call_out_transition (12);

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b1) )
      call_out_transition (15);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (16);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (17);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (58);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (18);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_more == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (19);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (20);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (21);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (59);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (22);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (23);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (24);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (25);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (60);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (26);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_MORE_PENDING)
         & (Prev_Master_Abort == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (   (prev_fifo_contains_data_more == 1'b1)
             | (prev_fifo_contains_data_last == 1'b1) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (27);

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b1) )
      call_out_transition (28);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (29);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b0)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (30);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b0)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (61);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (31);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (32);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (33);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (34);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (62);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (35);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (36);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (37);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (38);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (63);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (39);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (40);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (41);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b1)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (42);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b1)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (64);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (43);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_data_last == 1'b0)
         & (prev_timeout_forces_disconnect == 1'b0)
         & (prev_fifo_contains_data_two_more == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (44);


    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b1) )
      call_out_transition (45);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (46);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (47);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (65);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (48);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (   (prev_fifo_contains_address == 1'b0)
             | (   (prev_fifo_contains_address == 1'b1)
                 & (prev_doing_config_reference == 1'b1) )
             | (prev_back_to_back_possible == 1'b0) )
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (49);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (50);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (51);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (66);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (52);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_LAST)
         & (Prev_Master_Abort == 1'b0)
         & (prev_fifo_contains_address == 1'b1)
         & (prev_doing_config_reference == 1'b0)
         & (prev_back_to_back_possible == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (53);

    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_AS_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b00) )
      call_out_transition (54);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_AS_LAST)
         & (pci_devsel_in_prev == 1'b1)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (55);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_AS_LAST)
         & (pci_devsel_in_prev == 1'b0)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b01) )
      call_out_transition (67);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_AS_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b10) )
      call_out_transition (56);
    if (   (PCI_Master_Prev_State[4:0] == PCI_MASTER_DATA_MORE_AS_LAST)
         & ({pci_trdy_in_prev, pci_stop_in_prev} == 2'b11) )
      call_out_transition (57);
  end
`endif  // VERBOSE_MASTER_DEVICE
// synopsys translate_on
endmodule

