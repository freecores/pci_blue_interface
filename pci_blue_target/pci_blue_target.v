//===========================================================================
// $Id: pci_blue_target.v,v 1.26 2001-10-04 09:30:48 bbeaver Exp $
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
//        Delayed Read reference, as described in the PCI Local Bus
//        Specification Revision 2.2, sections 3.3.3.3 and 3.7.5.
//
// NOTE:  This Target State Machine must be careful if an Address Parity
//        error is detected.  See the PCI Local Bus Specification Revision
//        2.2, section 3.7.3 for details.
//
// NOTE:  This Target State Machine must look at the bottom 2 bits of the
//        address for all references (except IO references).  If the
//        bottom 2 bits are not both 0, the transfer should be terminated
//        with data after the first data phase.  See the PCI Local Bus
//        Specification Revision 2.2, section 3.2.2.2 for details.
//
// NOTE:  This Target State Machine is aware that a write might occur while
//        a Delayed Read is begin done, and the write might hit on top of
//        prefetched read data.  This Target State Machine indicates the
//        possibility of data corruption to the host side of the interface.
//
//===========================================================================

`timescale 1ns/10ps

module pci_blue_target (
// Signals driven to control the external PCI interface
  pci_ad_in_prev,
  pci_target_ad_out_next,
  pci_target_ad_en_next, pci_target_ad_out_oe_comb,
  pci_idsel_in_prev,
  pci_cbe_l_in_prev,
  pci_par_in_critical, pci_par_in_prev,
  pci_target_par_out_next,
  pci_target_par_out_oe_comb,
  pci_frame_in_critical, pci_frame_in_prev,
  pci_irdy_in_critical, pci_irdy_in_prev,
  pci_devsel_out_next,
  pci_trdy_out_next,
  pci_stop_out_next,
  pci_d_t_s_out_oe_comb,
  pci_perr_in_prev,
  pci_target_perr_out_next,
  pci_target_perr_out_oe_comb,
  pci_serr_in_prev,
  pci_target_serr_out_oe_comb,
// Signals to control shared AD bus, Parity, and SERR signals
  Target_Force_AD_to_Data,
  Target_Exposes_Data_On_IRDY,
  Target_Forces_PERR,
// Signal from Master to say that DMA data should be captured into Response FIFO
  Master_Captures_Data_On_TRDY,
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  pci_response_fifo_type,
  pci_response_fifo_cbe,
  pci_response_fifo_data,
  pci_response_fifo_room_available_meta,
  pci_response_fifo_two_words_available_meta,
  pci_response_fifo_data_load,
  pci_response_fifo_error,
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  pci_delayed_read_fifo_type,
  pci_delayed_read_fifo_data,
  pci_delayed_read_fifo_data_available_meta,
  pci_delayed_read_fifo_data_unload,
  pci_delayed_read_fifo_error,
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  master_to_target_status_type,
  master_to_target_status_cbe,
  master_to_target_status_data,
  master_to_target_status_flush,
  master_to_target_status_available,
  master_to_target_status_two_words_free,
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
// Courtesy indication that PCI Interface Config Register contains an error indication
  target_config_reg_signals_some_error,
  pci_clk,
  pci_reset_comb
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

// Signals driven to control the external PCI interface
  input  [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  output [PCI_BUS_DATA_RANGE:0] pci_target_ad_out_next;
  output  pci_target_ad_en_next;
  output  pci_target_ad_out_oe_comb;
  input   pci_idsel_in_prev;
  input  [PCI_BUS_CBE_RANGE:0] pci_cbe_l_in_prev;
  input   pci_par_in_critical;
  input   pci_par_in_prev;
  output  pci_target_par_out_next;
  output  pci_target_par_out_oe_comb;
  input   pci_frame_in_critical;
  input   pci_frame_in_prev;
  input   pci_irdy_in_critical;
  input   pci_irdy_in_prev;
  output  pci_devsel_out_next;
  output  pci_trdy_out_next;
  output  pci_stop_out_next;
  output  pci_d_t_s_out_oe_comb;
  input   pci_perr_in_prev;
  output  pci_target_perr_out_next;
  output  pci_target_perr_out_oe_comb;
  input   pci_serr_in_prev;
  output  pci_target_serr_out_oe_comb;
// Signals to control shared AD bus, Parity, and SERR signals
  output  Target_Force_AD_to_Data;
  output  Target_Exposes_Data_On_IRDY;
  output  Target_Forces_PERR;
// Signal from Master to say that DMA data should be captured into Response FIFO
  input   Master_Captures_Data_On_TRDY;
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  output [PCI_BUS_CBE_RANGE:0] pci_response_fifo_type;
  output [PCI_BUS_CBE_RANGE:0] pci_response_fifo_cbe;
  output [PCI_BUS_DATA_RANGE:0] pci_response_fifo_data;
  input   pci_response_fifo_room_available_meta;
  input   pci_response_fifo_two_words_available_meta;
  output  pci_response_fifo_data_load;
  input   pci_response_fifo_error;
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  input  [2:0] pci_delayed_read_fifo_type;
  input  [PCI_BUS_DATA_RANGE:0] pci_delayed_read_fifo_data;
  input   pci_delayed_read_fifo_data_available_meta;
  output  pci_delayed_read_fifo_data_unload;
  input   pci_delayed_read_fifo_error;
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  input  [2:0] master_to_target_status_type;
  input  [PCI_BUS_CBE_RANGE:0] master_to_target_status_cbe;
  input  [PCI_BUS_DATA_RANGE:0] master_to_target_status_data;
  input   master_to_target_status_flush;
  input   master_to_target_status_available;
  output  master_to_target_status_two_words_free;
  output  master_to_target_status_unload;
// Signals from the Master to the Target to set bits in the Status Register
  input   master_got_parity_error;
  input   master_caused_serr;
  input   master_caused_master_abort;
  input   master_got_target_abort;
  input   master_caused_parity_error;
// Signals used to document Master Behavior
  input   master_asked_to_retry;
// Signals from the Config Regs to the Master to control it.
  output  master_enable;
  output  master_fast_b2b_en;
  output  master_perr_enable;
  output  master_serr_enable;
  output [7:0] master_latency_value;
// Courtesy indication that PCI Interface Config Register contains an error indication
  output  target_config_reg_signals_some_error;
  input   pci_clk;
  input   pci_reset_comb;

// The PCI Blue Target gets data from the pci_delayed_read_fifo.
// There are 2 main types of entries:
// 1) Data sequences which are driven to the PCI bus (or discarded in the
//      Master terminates the burst early, the usual case!)
// 2) Data indicating it is the LAST ENTRY in a sequence, used to mark
//      the end of one burst and the beginning of another.  When the
//      PCI interface flushes the FIFO, it flushes until it unloads
//      a Last Data Item;

// Use standard FIFO prefetch trick to allow a single flop to control the
//   unloading of the whole FIFO.
  reg    [2:0] delayed_read_fifo_type_reg;
  reg    [PCI_BUS_DATA_RANGE:0] delayed_read_fifo_data_reg;
  wire    prefetching_delayed_read_fifo_data;  // forward reference

  always @(posedge pci_clk)
  begin
    if (prefetching_delayed_read_fifo_data == 1'b1)
    begin  // latch whenever data available and not already full
      delayed_read_fifo_type_reg[2:0] <= pci_delayed_read_fifo_type[2:0];
      delayed_read_fifo_data_reg[PCI_BUS_DATA_RANGE:0] <=
                      pci_delayed_read_fifo_data[PCI_BUS_DATA_RANGE:0];
// synopsys translate_off
`ifdef CALL_OUT_TARGET_STATE_TRANSITIONS
//       $display ("%m PCI Target prefetching data from Delayed Read FIFO %x %x, at time %t",
//                   pci_delayed_read_fifo_type[2:0],
//                   pci_delayed_read_fifo_data[PCI_BUS_DATA_RANGE:0], $time);
`endif  // CALL_OUT_TARGET_STATE_TRANSITIONS
// synopsys translate_on
    end
    else if (prefetching_delayed_read_fifo_data == 1'b0)  // hold
    begin
      delayed_read_fifo_type_reg[2:0] <= delayed_read_fifo_type_reg[2:0];
      delayed_read_fifo_data_reg[PCI_BUS_DATA_RANGE:0] <=
                      delayed_read_fifo_data_reg[PCI_BUS_DATA_RANGE:0];
    end
// synopsys translate_off
    else
    begin
      delayed_read_fifo_type_reg[2:0] <= 3'hX;
      delayed_read_fifo_data_reg[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
    end
// synopsys translate_on
  end

  wire    Target_Consumes_Delayed_Read_FIFO_Data_Unconditionally_Critical;  // forward reference
  wire    Target_Offering_Delayed_Read_Last = prefetching_delayed_read_fifo_data
                      & (   (pci_delayed_read_fifo_type[2:0] ==  // unused
                                    PCI_HOST_DELAYED_READ_DATA_VALID_LAST)
                          | (pci_delayed_read_fifo_type[2:0] ==  // fence or register access
                                    PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR));

// Target Request Full bit indicates when data prefetched on the way to PCI bus
// Single FLOP is used to control activity of this FIFO.
// NOTE: IRDY is VERY LATE.  This must be implemented to let IRDY operate quickly
// FIFO data is consumed if Target_Consumes_Request_FIFO_Data_Unconditionally_Critical
//                       or Target_Captures_Request_FIFO_If_IRDY and IRDY
// If not unloading and not full and no data,  not full
// If not unloading and not full and data,     full
// If not unloading and full and no data,      full
// If not unloading and full and data,         full
// If unloading and not full and no data,      not full
// If unloading and not full and data,         not full
// If unloading and full and no data,          not full
// If unloading and full and data,             full
  reg     target_delayed_read_full;  // forward reference
  wire    Target_Consumes_Delayed_Read_FIFO_If_IRDY;  // forward reference

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      target_delayed_read_full <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      if (pci_irdy_in_critical == 1'b1)  // pci_trdy_in_critical is VERY LATE
      begin
        target_delayed_read_full <=
            (   Target_Consumes_Delayed_Read_FIFO_Data_Unconditionally_Critical
              | Target_Consumes_Delayed_Read_FIFO_If_IRDY )
            ? (target_delayed_read_full & prefetching_delayed_read_fifo_data)   // unloading
            : (target_delayed_read_full | prefetching_delayed_read_fifo_data);  // not unloading
      end
      else if (pci_irdy_in_critical == 1'b0)
      begin
        target_delayed_read_full <=
                Target_Consumes_Delayed_Read_FIFO_Data_Unconditionally_Critical
            ? (target_delayed_read_full & prefetching_delayed_read_fifo_data)   // unloading
            : (target_delayed_read_full | prefetching_delayed_read_fifo_data);  // not unloading
      end
// synopsys translate_off
      else
      begin
        target_delayed_read_full <= 1'bX;
      end
// synopsys translate_on
    end
// synopsys translate_off
    else
    begin
      target_delayed_read_full <= 1'bX;
    end
// synopsys translate_on
  end

// Deliver data to the IO pads when needed.
  wire   [2:0] pci_delayed_read_fifo_type_current =
                        prefetching_delayed_read_fifo_data
                      ? pci_delayed_read_fifo_type[2:0]
                      : delayed_read_fifo_type_reg[2:0];
  wire   [PCI_BUS_DATA_RANGE:0] pci_delayed_read_fifo_data_current =
                        prefetching_delayed_read_fifo_data
                      ? pci_delayed_read_fifo_data[PCI_BUS_DATA_RANGE:0]
                      : delayed_read_fifo_data_reg[PCI_BUS_DATA_RANGE:0];

// Create Data Available signals which depend on the FIFO, the Latch, AND the
//   input of the status datapath, which can prevent the unloading of data.
  wire    delayed_read_fifo_data_available_meta =
                        (   pci_delayed_read_fifo_data_available_meta
                          | target_delayed_read_full);  // available

// Calculate whether to unload data from the Request FIFO
  wire    master_to_target_status_loadable;  // forward reference
  assign  prefetching_delayed_read_fifo_data =
                                  pci_delayed_read_fifo_data_available_meta
                                & ~target_delayed_read_full;
  assign  pci_delayed_read_fifo_data_unload = prefetching_delayed_read_fifo_data;  // drive outputs

/*
// NOTE: WORKING: This is a copy of what was in the FIFO.  It is also implemented above.

// FIFO Data Available Flag, which hopefully can operate with an
// Unload signal which has a MAX of 3 nSec setup time to the read clock.
  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
    if (pci_reset_comb == 1'b1)
    begin
      write_buffer_full_reg <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      if (write_submit)  // NOTE write_submit is VERY LATE.  3 nSec before clock
      begin
        write_buffer_full_reg <=  // only say full if no more room available
                      write_buffer_full_reg | ~write_room_available_meta_raw;
      end
      else  // ~write_submit
      begin
        write_buffer_full_reg <=  // say valid if any data available
                      write_buffer_full_reg & ~write_room_available_meta_raw;
      end
    end
    else
    begin
      write_buffer_full_reg <= 1'bX;
    end
  end

// Indicate to Fifo Instantier that room is available on the Write Port.
  assign  write_room_available_meta =
                     write_room_available_meta_raw | ~write_buffer_full_reg;       

// Move data from holding register to FIFO whenever there is room.
  assign  write_submit_int = write_room_available_meta_raw
                          & write_buffer_full_reg;

// Capture new data to the holding register if it is certain that the
// FIFO will consume the data in there now.
  always @(posedge write_clk)
  begin
    write_data_reg[39:0] = write_submit_int
                         ? write_data[39:0] : write_data_reg[39:0];
  end

// Pass buffered data to the FIFO.
  assign  write_data_int[38:0] = write_buffer_full_reg
                        ? write_data_reg[38:0] : write_data[38:0];
 */

// Add an extra level of pipelining to the PCI Response FIFO.  The IO pads
//   have flops in them, but the flops can't hold.  The extra level of flops
//   on the way to the Response FIFO lets the target safely say that 2 words
//   of storage are available.
//
// NOTE: IRDY and TRDY are already latched, so this set of flops does not help
//   the loading on these critical signals.  All the fancy stuff seems to be on
//   the read side.
// NOTE: On incoming data, I decided to delay the insertion of the data into
//   the FIFO until Parity is valid, one clock later.  The Parity Signal In
//   is the actual combinational parity data, so it needs to be super-fast
//   on the way to the Response FIFO.  It will be written into one of the
//   flops, which I HOPE are implemented as enablable flops, not with an
//   explicit external hold circuit.
// NOTE: This makes ALL PCI READS done by the Master, and ALL PCI ACTIVITY
//   initialized by an external master, take 1 clock longer than it needs to.
//   It simplifies the Host Interface, however, and makes it more likely
//   that the user will use the interface correctly.


// Watch Master Activity as indicated by the Master_To_Target_Status
// Want to know when a Read or Fence are being done.
// NOTE: This Status Info is actually available BEFORE OR AT THE SAME TIME
//   as the data is presented to the PCI bus.
  parameter WAITING_FOR_READ_OR_FENCE = 3'b000;
  parameter DOING_FENCE               = 3'b001;
  parameter DOING_READ                = 3'b010;
  parameter ENDING_READ               = 3'b011;
  parameter DOING_REGISTER            = 3'b101;
  parameter DOING_WRITE               = 3'b110;
  parameter ENDING_WRITE              = 3'b111;

  reg   [2:0] Master_Able_To_Block_During_Delayed_Read;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Master_Able_To_Block_During_Delayed_Read[2:0] <= WAITING_FOR_READ_OR_FENCE;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      if (   (master_to_target_status_available == 1'b1)
           & (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_INSERT_WRITE_FENCE)
           & (master_to_target_status_data[17:16] == 2'b00) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= DOING_FENCE;
      end
      else if (   (master_to_target_status_available == 1'b1)
                & (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_INSERT_WRITE_FENCE)
                & (master_to_target_status_data[17:16] != 2'b00) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= DOING_REGISTER;
      end
      else if (   (master_to_target_status_available == 1'b1)
                & (   (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_ADDRESS_COMMAND)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR) )
                & ((master_to_target_status_cbe[PCI_BUS_CBE_RANGE:0]
                                     & PCI_COMMAND_ANY_WRITE_MASK)
                                        == `PCI_BUS_CBE_ZERO) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= DOING_READ;
      end
      else if (   (master_to_target_status_available == 1'b0)
                & (Master_Able_To_Block_During_Delayed_Read[1:0] == DOING_READ) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= DOING_READ;
      end
      else if (   (master_to_target_status_available == 1'b1)
                & (Master_Able_To_Block_During_Delayed_Read[1:0] == DOING_READ)
                & (   (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) ) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= ENDING_READ;
      end
      else if (   (master_to_target_status_available == 1'b1)
                & (   (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_ADDRESS_COMMAND)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR) )
                & ((master_to_target_status_cbe[PCI_BUS_CBE_RANGE:0]
                                     & PCI_COMMAND_ANY_WRITE_MASK)
                                        != `PCI_BUS_CBE_ZERO) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= DOING_WRITE;
      end
      else if (   (master_to_target_status_available == 1'b0)
                & (Master_Able_To_Block_During_Delayed_Read[1:0] == DOING_WRITE) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= DOING_WRITE;
      end
      else if (   (master_to_target_status_available == 1'b1)
                & (Master_Able_To_Block_During_Delayed_Read[1:0] == DOING_WRITE)
                & (   (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST)
                    | (master_to_target_status_type[2:0] ==
                                   PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR) ) )
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= ENDING_WRITE;
      end
      else  // between references
      begin
        Master_Able_To_Block_During_Delayed_Read[2:0] <= WAITING_FOR_READ_OR_FENCE;
      end
    end
    else
    begin
      Master_Able_To_Block_During_Delayed_Read[2:0] <= 2'bX;
    end
  end

// Pass Register Read/Write commands from the Status Register to the Response
//   FIFO.  This can of course only happen if the Status Register is available.
//   On reads, the data must be substituted for the data from the Host.
// Pass Write data from the Status register to the Response FIFO unchanged.
// Pass the Request FIFO Fence through to the Response FIFO, but ONLY when
//   it is not held off because of a synchronization due to a delayed read.
// Pass the Read Command and Read Data CBE info from the Status Register
//   to the Response FIFO, but ONLY when it is not held off because of a
//   synchronization due to a delayed read.
// NOTE: The Response FIFO needs to get the Read Data, which is available in
//   the IO pad Flops, and it must get the Read Data Parity Error indication.
//   The Read Parity Error Indication is calculated based in the Latched
//   Parity Info and the critical direct Parity IN.  The Parity Error Info
//   must be calculated early enough that it can set up into the Response FIFO.
// Last but not least, note that Read traffic means that the Read Byte Enables
//   and Read Command must be unloaded early from the Status FIFO, to allow
//   the next word to be ready to issue.  That means that the info might be
//   unloaded before the Target returns data.  Carefully monitor the
//   Latched (!) Frame and IRDY signals to see when to proceed.

  wire    Holding_Off_Reads_And_Fences_Due_To_Delayed_Read;
  wire    Holding_Off_Register_References_Due_To_PCI_Activity;


// First get Fence, Register Read/Write, Master Write, Master Read.

// Plan: Add an extra level of pipelining on the AD bus(?).  I think this MIGHT be
//       necessary because sometimes the FIFO may be full, but data comes in.
//       In the case of the Master, it must be combined with the Master info before
//       it is stuck into the FIFO
// Plan: Move Address Match into Config Registers?  Make this not care about
//       the number and size of Config Registers.
// Plan: Make a very critical way to write parity info into the FIFO directly
//       from the external signal.  I want that Parity info to go in at the SAME
//       time as the data does.  (The data is latched in the IO pads, and
//       might also be held in the extra layer of flops.)
// Plan: Doesn't seem to be much else tricky needed.  Make the Delayed Read
//       collision detector look at present address, present address + 256 or
//       some large number, so the present address doesn't need to be updated
//       very often!
// Plan: want to terminate burst when hitting end of Base Address range.
//       More subtly, want to disconnect when CROSSING Base Address
//       boundries.  This is because the Host hardware may be too stupid
//       to handle this.  Certainly might be the case when writing!
//       But doesn;t this require the Address to be up-to-date all the time?
//       Might get away with having a signal which is a little early.
//       MIGHT just force all references within epsilon of the Base Address
//       register boundry to go as single-word references!
// Plan: Understand the protocol to allow a delayed read, then writes, then BACK
//       to the delayed read.  The CBE wires are one, the other, then back.
//       Make sure this understands that detail.


// Signals driven to control the external PCI interface
  wire   [PCI_BUS_DATA_RANGE:0] pci_config_write_data;
  wire   [PCI_BUS_DATA_RANGE:0] pci_config_read_data;
  wire   [PCI_BUS_DATA_RANGE:0] pci_config_address;
  wire   [PCI_BUS_CBE_RANGE:0] pci_config_byte_enables;
  wire    pci_config_write_req;

// Signals from the Config Registers to enable features in the Master and Target
  wire    target_memory_enable;
  wire    target_perr_enable, either_perr_enable;
  wire    target_serr_enable, either_serr_enable;

// Signals from the Master or the Target to set bits in the Status Register
  wire    target_caused_abort;
  wire    target_caused_serr, either_caused_serr;
  wire    target_got_parity_error, either_got_parity_error;

// drive shared signal to master; combine shared signals to Config Regs
  assign  target_perr_enable = either_perr_enable;
  assign  target_serr_enable = either_serr_enable;
  assign  master_perr_enable = either_perr_enable;
  assign  master_serr_enable = either_serr_enable;
  assign  either_caused_serr = master_caused_serr | target_caused_serr;
  assign  either_got_parity_error = master_got_parity_error | target_got_parity_error;

/* NOTE: Planning on removing comments
// Responses the PCI Controller sends over the Host Response Bus to indicate that
//   progress has been made on transfers initiated over the Request Bus by the Host.
// First, the Response which indicates that nothing should be put in the FIFO.
`define PCI_HOST_RESPONSE_SPARE                          (4'h0)
// Second, a Response saying when the Write Fence has been disposed of.  After this
//   is received, and the Delayed Read done, it is OK to queue more Write Requests.
// This command will be returned in response to a Request issued with Data
//   Bits 16 and 17 both set to 1'b0.
`define PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE          (4'h1)
// Third, a Response used to read and write the local PCI Controller's Config Registers.
// This Response shares it's tags with the WRITE_FENCE Command.  Config References
//   can be identified by noticing that Bits 16 or 17 are non-zero.
// Data Bits [7:0] are the Byte Address of the Config Register being accessed.
// Data Bits [15:8] are the single-byte Read Data returned when writing the Config Register.
// Data Bit  [16] indicates that a Config Write has been done.
// Data Bit  [17] indicates that a Config Read has been done.
// Data Bits [20:18] are used to select individual function register sets in the
//   case that a multi-function PCI interface is created.
// This Response will be issued with either Data Bits 16 or 17 set to 1'b1.
// `define PCI_HOST_RESPONSE_READ_WRITE_CONFIG_REGISTER  (4'h1)
// Fourth, a Response repeating the Host Request the PCI Bus is presently servicing.
`define PCI_HOST_RESPONSE_EXECUTED_ADDRESS_COMMAND       (4'h2)
// Fifth, a Response which gives commentary about what is happening on the PCI bus.
// These bits follow the layout of the PCI Config Register Status Half-word.
// When this Response is received, bits in the data field indicate the following:
// Bit 31: PERR Detected (sent if a Parity Error occurred on the Last Data Phase)
// Bit 30: SERR Detected
// Bit 29: Master Abort received
// Bit 28: Target Abort received
// Bit 27: Caused Target Abort
// Bit 24: Caused PERR
// Bit 19: Flush Read/Write data due to Master Abort or Target Abort
// Bit 18: Discarded a Delayed Read due to timeout
// Bit 17: Target Retry or Disconnect (document that a Master Retry is requested)
// Bit 16: Got Illegal sequence of commands over Host Request Bus.
`define PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT     (4'h3)
// Sixth, Responses indicating that Write Data was delivered, Read Data is available,
//   End Of Burst, and that a Parity Error occurred the previous data cycle.
// NOTE:  If a Master or Target Abort happens, the contents of the Request
//   FIFO will be flushed until the DATA_LAST is removed.  The Response FIFO
//   will have a FLUSH entry for each data item flushed by the Master.
`define PCI_HOST_RESPONSE_R_DATA_W_SENT                  (4'h4)
`define PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST             (4'h5)
`define PCI_HOST_RESPONSE_R_DATA_W_SENT_PERR             (4'h6)
`define PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR        (4'h7)

// Writes from an External PCI Master can be completed immediately based on
//   information available on the Host Response Bus.
// Reads from an External PCI Master need to be completed in several steps.
// First, the Address, Command, and one word containing a Read Mask are received.
// Second, upon receiving a Response indicating that Read is being started, the Host
//   controller must either issue a Write Fence onto the Host Request Bus.
// Third the Host Controller must start putting Read Data into the Delayed_Read_Data
//   FIFO.  The Host Controller can indicate End Of Burst or Target Abort there too.
// The Host Controller must continue to service Write Requests while the Delayed Read
//   is being acted on.   See the PCI Local Bus Spec Revision 2.2 section 3.3.3.3.4
//   for details.
// If Bus Writes are done while the Delayed Read Data is being fetched, the PCI
//   Bus Interface will watch to see if any writes overlap the Read address region.
//   If a Write overlaps the Read address region, the PCI Interface will ask that the
//   Read be re-issued.  The PCI Interface will also start flushing data out of
//   the Delayed_Read_Data FIFO until a DATA_LAST entry is found.  The Host Intrface
//   is REQUIRED to put one DATA_LAST or TARGET_ABORT entry into the Delayed_Read_Data
//   FIFO after being instructed to reissue a Delayed Read.  All data up to and
//   including that last entry will be flushed, and data following that point will
//   be waited for to satisfy the Delayed Read Request.
// Tags the Host Controller sends across the Delayed_Read_Data FIFO to indicate
//   progress made on transfers initiated by the external PCI Bus Master.
`define PCI_HOST_DELAYED_READ_DATA_SPARE               (3'b000)
`define PCI_HOST_DELAYED_READ_DATA_VALID               (3'b001)
`define PCI_HOST_DELAYED_READ_DATA_VALID_LAST          (3'b010)
`define PCI_HOST_DELAYED_READ_DATA_VALID_PERR          (3'b101)
`define PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR     (3'b110)
`define PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT        (3'b011)
*/

// The Target State Machine has a pretty easy existence.  It responds
//   at leasure to the transition of FRAME_L from unasserted HIGH to
//   asserted LOW.
// It captures Write Data, but the data can be pipelined on the way
//   to the Receive Data Fifo.
// It delivers Read Data.  Here it must be snappy.  When IRDY_L and
//   TRDY_L are both asserted LOW, it must deliver new data the next
//   rising edge of the PCI clock to be zero-wait-state.
// The Target State Machine ends a transfer when it sees FRAME_L go
//   HIGH again under control of the master, or whenever it wants under
//   control of the slave.
//
// The Target State Machine has one difficult task to perform.  It must
//   make sure that the PCI Ordering Rules are followed.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.2 for details.
//
// In the simplest case, the Target executes writes immediately, and
//   it also completes Reads immediately.  This is true for Config Refs.
//
// To make better use of the PCI Bus, this interface implements a
//   Delayed Read function.  When it gets a Read to Memory, it assumes
//   that it cannot respond quickly enough.  It does a Retry, causing
//   the requestor to wait at least 2 clocks, then request again.
//
// In the simplest case, the Requestor immediately retries and the
//   transfer completes.  The Response FIFO will ensure that all writes
//   previously issued by External PCI devices will complete before the
//   read completes, which is required by the ordering rules.
//
// Unfortunately, several complicated things can happen instead.
//
// First, this device's Master might have some Writes queued.  All of these
//   writes must complete before the Read completes.  This is achieved
//   by putting a Write Fence in the Master Request FIFO, and holding off
//   the Delayed Read completion until the Write Fence is unloaded.  Once
//   the Write Fence is issued, the Master cannot execute any more Writes
//   until the Delayed Read completes.
// Second, this device's Master might have a single Read queued.  A Read
//   serves the same function as a write fence.  The Delayed Read cannot
//   complete until the Master Read gets to the front of the Request FIFO.
//   The Master cannot execute any references until it's Read is complete,
//   and in addition it cannot issue any references until the Delayed
//   read completes.
// Third, external PCI Devices might execute Writes to this device after the
//   Delayed Read starts, but before it completes.  These must all be allowed
//   to complete.  In the simple case, all of these Writes are to areas of
//   memory away from where the Delayed Read is being executes.
// Fourth, external PCI devices might execute Writes to this device which hit
//   right on top of where the Delayed Read is being executed.  If this happens,
//   then since the Write must be allowed to complete, the Delayed Read will
//   have fetched OLD DATA from DRAM.  The Delayed Read Data must be flushed,
//   and the Delayed Read must restart to fetch the new data.  This is achieved
//   by putting a Data Fence inthe Delayed Read Data FIFO.  Once it is issued,
//   the Target will discard all data from the FIFO until it sees the Fence.
//   The Target won't fetch any more data until it knows that the Data Fence
//   has been removed from the FIFO.  This is hoped to reduce the number of
//   Write Fences to 0 or 1 MAX.  Once the Fence is unloaded, the Target
//   will ask that data be re-fetched.  The FIFO will contain data after the
//   restart which reflects the new memory contents.
// Fifth, the Response FIFO must contain both Write Data from external PCI
//   devices, and Read Byte Enables from the initial Delayed Reader.  The
//   FIFO must be able to indicate when the Byte Enables reflect Read info
//   after a string of Writes.  This is achieved by marking the Byte Enables
//   for the 2nd and subsequent Read cycles in the FIFO as Delayed Read Enables.
//
// There seems to be one unfortunate case which I do not know how to deal with.
//   Assume that this device's Master issued a Read, which was Retried by a
//   remote device.  Then THAT device issues a Read to this target, and the
//   Read is also retried.  Assume further that both the Remote device and this
//   Device cannot complete the Delayed Read until they execute one or more Writes.
// Neither device can issue writes, because they have Reads pending!  It seems
//   that maybe this device cannot issue a Read after it has started a Delayed Read
//   transaction to a remote device.  Also, in general if a Read is outstanding,
//   this device cannot require that it be able to do Writes before an external
//   read is allowed to complete.  It also seems generally a good idea to NOT
//   issue more writes after a Read is queued.  This interface should only use
//   the time to flush writes which have already been issued.  Writes should NOT
//   be required after a Read is accepted, but before the Read completes, unless
//   this device has no Reads outstanding.  This needs more thought.
//
// There needs to be a State Machine which reflects the handshakes between
//   the Target and the Master for the Write Fence, and between the Target
//   and the DRAM interface to handle flushing of the Delayed Read FIFO.
// This State Machine sits above the PCI Target State Machine described in
//   the PCI Local Bus Spec Revision 2.2

// Classify the content of the Response FIFO, taking into account the Target
// Enable bit and the Delayed Read FIFO empty Bit, as well as the Master
// FIFO activity.
  wire   Delayed_Read_FIFO_Empty = 1'b0;  // NOTE: WORKING
  wire   Delayed_Read_FIFO_CONTAINS_ABORT = 1'b0;
  wire   Delayed_Read_FIFO_CONTAINS_DATA_MORE = 1'b0;
  wire   Delayed_Read_FIFO_CONTAINS_DATA_LAST = 1'b0;

// Target Initial Latency Counter.  Must respond within 16 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.1.1 for details.
// NOTE: It would be better to ALWAYS make every Memory read into a Delayed Read!

  reg    [2:0] Target_Initial_Latency_Counter;
  reg     Target_Initial_Latency_Disconnect;

  always @(posedge pci_clk)
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Target_Initial_Latency_Counter[2:0] <= 3'h0;
      Target_Initial_Latency_Disconnect <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
    end
    else
    begin  // NOTE: WORKING
    end
  end

// Target Subsequent Latency Counter.  Must make progress within 8 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.1.2 for details.

  reg    [2:0] Target_Subsequent_Latency_Counter;
  reg     Target_Subsequent_Latency_Disconnect;

  always @(posedge pci_clk)
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Target_Subsequent_Latency_Counter[2:0] <= 3'h0;
      Target_Subsequent_Latency_Disconnect <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
    end
    else
    begin  // NOTE: WORKING
    end
  end

// Keep track of the present PCI Address, so the Target can respond
//   to the Delayed Read request when it is issued.
// Configuration References will NOT result in Delayed Reads.
// All other reads will become Delayed Reads, and a Read can be
//   further delayed if data does not arrive soon enough in the
//   middle of a Burst.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.1.1 and
// 3.5.1.2 for details.
// The bottom 2 bits of a PCI Address have special meaning to the
// PCI Master and PCI Target.  See the PCI Local Bus Spec
// Revision 2.2 section 3.2.2.1 and 3.2.2.2 for details.

  reg    [PCI_BUS_DATA_RANGE:0] Delayed_Read_Address;
  reg    [PCI_BUS_CBE_RANGE:0] Delayed_Read_Command;
  reg    [PCI_BUS_CBE_RANGE:0] Delayed_Read_Byte_Strobes;
  reg     Delayed_Read_Address_Parity;
  reg     Grab_Target_Address, Prev_Grab_Target_Address, Inc_Target_Address;

  always @(posedge pci_clk)
  begin
    if (Grab_Target_Address == 1'b1)
    begin
      Delayed_Read_Address[PCI_BUS_DATA_RANGE:0] <= pci_ad_in_prev[PCI_BUS_DATA_RANGE:0];
      Delayed_Read_Command[PCI_BUS_CBE_RANGE:0] <= pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0];
      Delayed_Read_Address_Parity <= 1'b0;  // NOTE WORKING
    end
    else if (Grab_Target_Address == 1'b0)
    begin
      if (Inc_Target_Address == 1'b1)
      begin
        Delayed_Read_Address[PCI_BUS_DATA_RANGE:0] <=
                          Delayed_Read_Address[PCI_BUS_DATA_RANGE:0]
                        + `PCI_BUS_Address_Step;
      end
      else if (Inc_Target_Address == 1'b0)
      begin
        Delayed_Read_Address[PCI_BUS_DATA_RANGE:0] <=
                               Delayed_Read_Address[PCI_BUS_DATA_RANGE:0];
      end
      else
      begin  // NOTE: WORKING
      end
      Delayed_Read_Command[PCI_BUS_CBE_RANGE:0] <=
                               Delayed_Read_Command[PCI_BUS_CBE_RANGE:0];
    end
    else
    begin  // NOTE: WORKING
    end
    Prev_Grab_Target_Address <= Grab_Target_Address;
    if ((Prev_Grab_Target_Address == 1'b1) || (Inc_Target_Address == 1'b1))
    begin
      Delayed_Read_Byte_Strobes[PCI_BUS_CBE_RANGE:0] <=
                               pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0];
    end
    else if ((Prev_Grab_Target_Address == 1'b0) && (Inc_Target_Address == 1'b0))
    begin
      Delayed_Read_Byte_Strobes[PCI_BUS_CBE_RANGE:0] <=
                               Delayed_Read_Byte_Strobes[PCI_BUS_CBE_RANGE:0];
    end
    else
    begin  // NOTE: WORKING
    end
  end

// Address Compare Logic to discover if a Read is being done to the same
//   address with the same command and Byte Strobes as the present Delayed Read.

  wire    Delayed_Read_Address_Match =
             & (Delayed_Read_Address[PCI_BUS_DATA_RANGE:0] ==
                                      pci_ad_in_prev[PCI_BUS_DATA_RANGE:0])
             & (Delayed_Read_Command[PCI_BUS_CBE_RANGE:0] ==
                                      pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0])
             & (Delayed_Read_Address_Parity == 1'b0)  // NOTE: WORKING
             & (Delayed_Read_Byte_Strobes[PCI_BUS_CBE_RANGE:0] ==
                                      pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0]);

// Delayed Read Discard Counter
// See the PCI Local Bus Spec Revision 2.2 section 3.3.3.3.3 for details.

  reg    [14:0] Delayed_Read_Discard_Counter;
  reg     Delayed_Read_Discard_Now;

  always @(posedge pci_clk)
  begin
    if (pci_reset_comb == 1'b1)
    begin
      Delayed_Read_Discard_Counter[14:0] <= 15'h7FFF;
      Delayed_Read_Discard_Now <= 1'b0;
    end
    else if (Grab_Target_Address == 1'b1)  // NOTE: WORKING
    begin
      Delayed_Read_Discard_Counter[14:0] <= 15'h0000;
      Delayed_Read_Discard_Now <= 1'b0;
    end
    else
    begin
      if (Delayed_Read_Discard_Counter[14:0] == 15'h7FFF)
      begin
        Delayed_Read_Discard_Counter[14:0] <= 15'h7FFF;
        Delayed_Read_Discard_Now <= 1'b0;
      end
      else
      begin
        Delayed_Read_Discard_Counter[14:0] <=
              Delayed_Read_Discard_Counter[14:0] + 15'h0001;
        Delayed_Read_Discard_Now <=
             (Delayed_Read_Discard_Counter[14:0] == 15'h7FFE);
      end
    end
  end

// Delayed Read In Progress Indicator

  parameter DELAYED_READ_NOT_ACTIVE = 2'b00;
  parameter DELAYED_READ_DATA_WAIT =  2'b00;
  parameter DELAYED_READ_FLUSH =      2'b00;
  parameter DELAYED_READ_FLUSH_DONE = 2'b00;

  reg    [1:0] PCI_Delayed_Read_State;

  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
    if (pci_reset_comb == 1'b1)
    begin
      PCI_Delayed_Read_State[1:0] <= DELAYED_READ_NOT_ACTIVE;
    end
    else if (pci_reset_comb == 1'b0)
    begin  // NOTE: WORKING
      if ((PCI_Delayed_Read_State[1:0] == DELAYED_READ_NOT_ACTIVE) && Delayed_Read_Discard_Now)
      begin
        PCI_Delayed_Read_State[1:0] <= DELAYED_READ_NOT_ACTIVE;  // NOTE WORKING
      end
      else
      begin
        PCI_Delayed_Read_State[1:0] <= DELAYED_READ_NOT_ACTIVE;  // NOTE WORKING
      end
    end
    else
    begin  // NOTE: WORKING
        PCI_Delayed_Read_State[1:0] <= DELAYED_READ_NOT_ACTIVE;  // NOTE WORKING
    end
  end

// Address Compare logic to discover whether a Write has been done to data
//   which is in the Delayed Read Prefetch Buffer.
// Assume here that the Prefetch Buffer contains 16 words of 8 bytes, or 128 bytes.
// NOTE: This will have to change if the FIFO were made longer, but is safe
//       if the Prefetch FIFO is 16 entries of 64 bits each.
// See the PCI Local Bus Spec Revision 2.2 section 3.2.5 for details.

  wire    Delayed_Read_Write_Collision =
                (pci_ad_in_prev[31:7] == Delayed_Read_Address[31:7])
              | (pci_ad_in_prev[31:7] == (Delayed_Read_Address[31:7]
                                                              + 25'h0000001) );

// Calculate the parity which is received due to an external Master sending
//   an Address or a Write Data item.
// NOTE: WORKING: This will have to be re-written for a 64-bit PCI interface
  wire    par_0 = (^pci_ad_in_prev[3:0]);
  wire    par_1 = (^pci_ad_in_prev[7:4]);
  wire    par_2 = (^pci_ad_in_prev[11:8]);
  wire    par_3 = (^pci_ad_in_prev[15:12]);
  wire    par_4 = (^pci_ad_in_prev[19:16]);
  wire    par_5 = (^pci_ad_in_prev[23:20]);
  wire    par_6 = (^pci_ad_in_prev[27:24]);
  wire    par_7 = (^pci_ad_in_prev[31:28]);
  wire    par_0_1 = par_0 ^ par_1 ^ pci_cbe_l_in_prev[0];
  wire    par_2_3 = par_2 ^ par_3 ^ pci_cbe_l_in_prev[1];
  wire    par_4_5 = par_4 ^ par_5 ^ pci_cbe_l_in_prev[2];
  wire    par_6_7 = par_6 ^ par_7 ^ pci_cbe_l_in_prev[2];
  wire    address_data_parity = par_0_1 ^ par_2_3 ^ par_4_5 ^ par_6_7;

// Classify the new reference based on the latched Command and sometimes
//   the IDSEL and address lines.

  wire    pci_config_ref =
                  (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_CONFIG_READ)  // NOTE: WORKING: address, idsel!
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_CONFIG_WRITE);
  wire    pci_mem_io_ref =
                  (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_IO_READ)  // NOTE: WORKING: address, idsel!
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_MEMORY_READ)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_MEMORY_READ_MULTIPLE)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_MEMORY_READ_LINE)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_IO_WRITE)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_MEMORY_WRITE)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_MEMORY_WRITE_INVALIDATE);
  wire    pci_invalid_command =
                  (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_INTERRUPT_ACKNOWLEDGE)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_SPECIAL_CYCLE)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_RESERVED_READ_4)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_RESERVED_WRITE_5)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_RESERVED_READ_8)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_RESERVED_WRITE_9)
                | (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] == PCI_COMMAND_DUAL_ADDRESS_CYCLE);

// The Target State Machine as described in Appendix B.
// No Lock State Machine is implemented.
// At this time, this device only supports 32-bit addresses.
// This design supports Medium Decode.  Fast Decode is not supported.
//
// At the beginning of a transfer, the Master asserts the Address and Command
//   information for the command.  FRAME was deasserted HIGH the previous clock
//   (IRDY was either value), and FRAME is asserted LOW this clock, while
//   IRDY is always deasserted HIGH.
// A very fast device might immediately assert DEVSEL using Fast Decode.
// This device latches the Address Info, and only asserts DEVSEL the next
//   clock.  This gives this state machine time to discover if the Address
//   the external PCI Device is asserting has the correct parity.
// NOTE: The Parity Path is a critical path for this design.
// NOTE: If this device wanted to support 64-bit addresses on a 32-bit bus,
//   it would have to delay the assertion of DEVSEL one extra clock to let
//   the larity bit be sampled for the second address word.
// NOTE: 64-bit addresses on a 64-bit bus are OK, because all data is
//   available the first clock.
// See the PCI Local Bus Spec Revision 2.2 section 3.9 for details.
//
// The Target might decide that the reference is not for us, either due to
//   an address mismatch, a command mismatch, or an address parity error.
// In all cases, no DEVSEL is created.
// The Target might know that the address DOES match this device.  In all
//   such cases, a DEVSEL is required.
// The Target can be in any state.  It is required to service Write Bursts
//   at all times.
// The Target might be idle.  If it is called upon to start a Read, it will
//   issue a RETRY and start a Delayed Read cycle.
// If the Target is in Delayed Read mode, it will issue a Retry for any
//   command which is not identical to the Read Command it is executing.
// If the Target is in Delayed Read mode, and the initial Read is re-issued,
//   and data is not available, the Target also issues a Delayed Read.
// Once in a Read or Write Burst, the Target might issue a Disconnect
//   without data if it is not able to service the Master request fast enough.
// The Target will also start issuing lots of Target Disconnects when the
//   address it is serving is close to the upper edge of the Base Address range.
//
// If the Target is serving a Delayed Read and the Master issues a Master
//   Termination, the Target needs to flush unused data out of the Delayed
//   Read FIFO.
// If the Target is working on a Delayed Read, and it services Write requests
//   at the same time, and a Write is so close to the present Read Address that
//   stale data might be in the Delayed Read FIFO, the Target needs to flush
//   the Delayed Read FIFO and ask for the data to be re-issued.
//
// Here is my interpretation of the Target State Machine:
//
// The Target is in one of 5 states when transferring data:
// 1) Waiting for an address,
// 2) Waiting for data,
// 3) Transferring data with more to come,
// 4) Transferring the last Data item.
// 5) Stopping a transfer
//
// The Target State Machine puts write data into the Response FIFO,
// but receives data in response to reads from the Delayed Read Data FIFO.
//
// The two FIFOs can indicate that they
// 1) contain no room or Read Data,
// 2) contain Data which is not the last
// 3) contain the last Data
// 4) are doing a retry, disconnect, or abort
//
// The Master can say that it wants a Wait State, that it wants
// to transfer Data, or that it wants to transfer the Last Data.
//


// NOTE: WORKING: get rid of this comment
// The State Sequence is as follows:
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_IDLE,        FIFO Don't care  0       0      0
// Master No Frame     0      X            0       0      0  -> TARGET_IDLE
// Master Frame        1      0            0       0      0  -> TARGET_ADDR
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_ADDR         FIFO Empty       0       0      0
// Write No Addr Match 1      X            0       0      0  -> TARGET_NOT_ME
// Write Addr Match,   1      X            1       0      0  -> TARGET_WAIT
// Read No Addr Match  1      X            0       0      0  -> TARGET_NOT_ME
// No Delayed Read     1      X            1       0      1  -> TARGET_STOP
// Delayed Read Match  1      X            1       0      0  -> TARGET_WAIT
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_ADDR         FIFO non-Last Data 0     0      0
// Write No Addr Match 1      X            0       0      0  -> TARGET_NOT_ME
// Write Addr Match,   1      X            1       1      0  -> TARGET_DATA_MORE
// Read No Addr Match  1      X            0       0      0  -> TARGET_NOT_ME
// No Delayed Read     1      X            1       0      0  -> TARGET_STOP
// Delayed Read Match  1      X            1       1      0  -> TARGET_DATA_MORE
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_ADDR         FIFO Last Data   0       0      0
// Write No Addr Match 1      X            0       0      0  -> TARGET_NOT_ME
// Write Addr Match,   1      X            1       1      1  -> TARGET_DATA_LAST
// Read No Addr Match  1      X            0       0      0  -> TARGET_NOT_ME
// No Delayed Read     1      X            1       0      0  -> TARGET_STOP
// Delayed Read Match  1      X            1       1      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_ADDR         FIFO Abort       0       0      0
// Write No Addr Match 1      X            0       0      0  -> TARGET_NOT_ME
// Write Addr Match,   1      X            1       0      0  -> TARGET_ABORT
// Read No Addr Match  1      X            0       0      0  -> TARGET_NOT_ME
// No Delayed Read     1      X            1       0      1  -> TARGET_STOP
// Delayed Read Match  1      X            1       0      0  -> TARGET_ABORT
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_WAIT,        FIFO Empty       1       1      0
// Master Wait         0      0            1       1      0  -> TARGET_WAIT
// Master Data         1      0            1       1      0  -> TARGET_WAIT
// Master Last Data    1      1            1       1      0  -> TARGET_WAIT
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_WAIT,        FIFO non-Last Data 0     1      0
// Master Wait         0      0            0       1      1  -> TARGET_DATA_MORE
// Master Data         1      0            0       1      1  -> TARGET_DATA_MORE
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_WAIT,        FIFO Last Data   0       1      0
// Master Wait         0      0            0       0      1  -> TARGET_DATA_LAST
// Master Data         1      0            0       0      1  -> TARGET_DATA_LAST
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_WAIT,        FIFO Abort       0       1      0
// Master Wait         0      0            0       0      1  -> TARGET_DATA_LAST
// Master Data         1      0            0       0      1  -> TARGET_DATA_LAST
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_DATA_MORE,   FIFO Empty       0       1      1
// Master Wait         0      0            0       1      1  -> TARGET_DATA_MORE
// Master Data         1      0            0       1      0  -> TARGET_WAIT
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_DATA_MORE,   FIFO non-Last Data       1      1
// Master Wait         0      0            0       1      1  -> TARGET_DATA_MORE
// Master Data         1      0            0       1      1  -> TARGET_DATA_MORE
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_DATA_MORE,   FIFO Last Data   0       1      1
// Master Wait         0      0            0       1      1  -> TARGET_DATA_MORE
// Master Data         1      0            0       0      1  -> TARGET_DATA_LAST
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_DATA_MORE,   FIFO Abort       0       1      1
// Master Wait         0      0            0       1      1  -> TARGET_DATA_MORE
// Master Data         1      0            0       0      1  -> TARGET_DATA_LAST
// Master Last Data    1      1            0       0      1  -> TARGET_DATA_LAST
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_DATA_LAST,   FIFO Empty       0       0      1 (or if no Fast Back-to-Back)
// Master Wait         0      0            0       0      1  -> TARGET_DATA_LAST
// Master Data         1      0            0       0      0  -> TARGET_IDLE
// Master Last Data    1      1            0       0      0  -> TARGET_IDLE
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_DATA_LAST,   FIFO Address     0       0      1 (and if Fast Back-to-Back)
// Master Don't Care   X      X            0       1      0  -> TARGET_ADDR
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_ABORT,       FIFO Empty       0       0      1 (or if no Fast Back-to-Back)
// Master Don't Care   X      X            0       0      0  -> TARGET_IDLE
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_STOP,        FIFO Empty       0       0      1 (or if no Fast Back-to-Back)
// Master Don't Care   X      X            0       0      0  -> TARGET_IDLE
//                   FRAME   IRDY        DEVSEL   TRDY   STOP
//    TARGET_STOP,        FIFO Address     0       0      1 (and if Fast Back-to-Back)
// Master Don't Care   X      X            0       1      0  -> TARGET_ADDR
//
// NOTE: that in all cases, the DEVSEL, TRDY, and STOP signals are calculated
//   based on the FRAME and IRDY signals, which are very late and very
//   timing critical.
//
// The functions will be implemented as a 4-1 MUX using FRAME and IRDY
//   as the selection variables.
//
// The inputs to the DEVSEL, TRDY, and STOP MUX's will be decided based
//   on the state the Target is in, and also on the contents of the
//   Delayed Read Data FIFO.

// State Variables are closely related to PCI Control Signals:
//  They are (in order) AD_OE, DEVSEL_L, TRDY_L, STOP_L, State_[1,0], HEX state value
  parameter PCI_TARGET_IDLE_000                   = 6'b0_000_00;  // 00 Idle
  parameter PCI_TARGET_NOT_ME_000                 = 6'b0_000_01;  // 01 Not Me

  parameter PCI_TARGET_CONFIG_READ_WAIT_100       = 6'b0_100_01;  // 11 DEVSEL Read
  parameter PCI_TARGET_CONFIG_READ_DATA_110       = 6'b0_110_01;  // 19 Read Data

  parameter PCI_TARGET_MEMORY_READ_WAIT_100       = 6'b0_100_00;  // 10 DEVSEL Read
  parameter PCI_TARGET_MEMORY_READ_DATA_110       = 6'b0_110_00;  // 18 Read Data
  parameter PCI_TARGET_MEMORY_READ_DATA_STOP_111  = 6'b0_111_00;  // 1C Read Data Stop
  parameter PCI_TARGET_MEMORY_READ_RETRY_101      = 6'b0_101_00;  // 14 Read Stop

  parameter PCI_TARGET_READ_ABORT_FIRST_100       = 6'b0_100_01;
  parameter PCI_TARGET_READ_ABORT_SECOND_001      = 6'b0_001_00;  // 04 Read Target Abort

  parameter PCI_TARGET_CONFIG_WRITE_WAIT_100      = 6'b1_100_01;  // 31 DEVSEL Write
  parameter PCI_TARGET_CONFIG_WRITE_DATA_110      = 6'b1_110_01;  // 39 Write Data

  parameter PCI_TARGET_MEMORY_WRITE_WAIT_100      = 6'b1_100_00;  // 30 DEVSEL Write
  parameter PCI_TARGET_MEMORY_WRITE_DATA_110      = 6'b1_110_00;  // 38 Write Data
  parameter PCI_TARGET_MEMORY_WRITE_DATA_STOP_111 = 6'b1_111_00;  // 3C Write Data Stop
  parameter PCI_TARGET_MEMORY_WRITE_RETRY_101     = 6'b1_101_00;  // 34 Write Stop

  parameter PCI_TARGET_WRITE_ABORT_FIRST_100      = 6'b1_100_01;
  parameter PCI_TARGET_WRITE_ABORT_SECOND_001     = 6'b1_001_00;  // 24 Write Target Abort

  parameter TS_Range = 5;
  parameter TS_X = {(TS_Range+1){1'bX}};

// Classify the activity of the External Master.
// These correspond to      {frame, irdy}, HEX state value
  parameter MASTER_IDLE      = 2'b00;
  parameter MASTER_WAIT      = 2'b10;
  parameter MASTER_DATA_MORE = 2'b11;
  parameter MASTER_DATA_LAST = 2'b01;

  reg     pci_frame_in_prev_prev, pci_irdy_in_prev_prev;  // forward reference

// Experience with the PCI Target interface teaches that the signals
//   FRAME and IRDY are extremely time critical.  These signals cannot be
//   latched in the IO pads.  The signals must be acted upon by the
//   Target State Machine as combinational inputs.
//
// There are two implementations of the logic below.  One uses a regular
//   CASE statement.  It is probably correct, but slow.  The second is
//   much more complicated, but uses the critical external signals only to
//   control a MUX which is right before flops.  The MUX is fast.
//
// The combinational logic is below.  This feeds into some Output Flops
//   which are right at the IO pads, and also some which capture the state.
// NOTE: THESE COULD BE THE SAME FLOPS if the timing could be guaranteed.
//   that would reduce loading on these critical signals.

// NOTE: FRAME and IRDY are VERY LATE.  This logic is in the critical path.

// Given a present Target State and all appropriate inputs, calculate the next state.
// Here is how to think of it for now: When a clock happens, this says what to do now.

// NOTE: Below are 4 functions.  Use a MUX to select between them based on FRAME, IRDY.
// NOTE: WORKING: I think that there should be a term including Parity, to make this
//       correctly allow Master Aborts on Addresses with Parity Errors.
// NOTE: For a term which is constant and not selected by FRAME or IRDY
//  (like jumping to IDLE), put it in both sides of a MUX.
// NOTE: Since I know IDLE is all 0's, leave those terms out to reduce typing.

// NOTE: DON"T DEBUG USING THIS FUNCTION.  Use the full function at the bottom
//       of the file.  This is a subset, derived from the full State Machine.
// FRAME and IRDY are {0, 0}
function [TS_Range:0] Target_Next_State_MASTER_IDLE;
  input  [TS_Range:0] Target_Present_State;
  input   Response_FIFO_has_Room;
  input   DELAYED_READ_FIFO_CONTAINS_DATA;
  input   Timeout_Forces_Disconnect;
  input   frame_in_prev;
  input   irdy_in_prev;
  input   frame_in_prev_prev;
  input   irdy_in_prev_prev;

  begin
    case (Target_Present_State[TS_Range:0])  // synopsys parallel_case
    default:
      begin
        Target_Next_State_MASTER_IDLE[TS_Range:0] = TS_X;  // error
// synopsys translate_off
        if ($time > 0)
          $display ("*** %m PCI Target State Machine Unknown %x at time %t",
                         Target_Next_State_MASTER_IDLE[TS_Range:0], $time);
// synopsys translate_on
      end
    endcase
  end
endfunction

// NOTE: DON"T DEBUG USING THIS FUNCTION.  Use the full function at the bottom
//       of the file.  This is a subset, derived from the full State Machine.
// FRAME and IRDY are {0, 1}
function [TS_Range:0] Target_Next_State_MASTER_WAIT;
  input  [TS_Range:0] Target_Present_State;
  input   Response_FIFO_has_Room;
  input   DELAYED_READ_FIFO_CONTAINS_DATA;
  input   Timeout_Forces_Disconnect;
  input   frame_in_prev;
  input   irdy_in_prev;
  input   frame_in_prev_prev;
  input   irdy_in_prev_prev;

  begin
    case (Target_Present_State[TS_Range:0])  // synopsys parallel_case
    default:
      begin
        Target_Next_State_MASTER_WAIT[TS_Range:0] = TS_X;  // error
// synopsys translate_off
        if ($time > 0)
          $display ("*** %m PCI Target State Machine Unknown %x at time %t",
                         Target_Next_State_MASTER_WAIT[TS_Range:0], $time);
// synopsys translate_on
      end
    endcase
  end
endfunction

// NOTE: DON"T DEBUG USING THIS FUNCTION.  Use the full function at the bottom
//       of the file.  This is a subset, derived from the full State Machine.
// FRAME and IRDY are {1, 1}
function [TS_Range:0] Target_Next_State_MASTER_DATA_MORE;
  input  [TS_Range:0] Target_Present_State;
  input   Response_FIFO_has_Room;
  input   DELAYED_READ_FIFO_CONTAINS_DATA;
  input   Timeout_Forces_Disconnect;
  input   frame_in_prev;
  input   irdy_in_prev;
  input   frame_in_prev_prev;
  input   irdy_in_prev_prev;

  begin
    case (Target_Present_State[TS_Range:0])  // synopsys parallel_case
    default:
      begin
        Target_Next_State_MASTER_DATA_MORE[TS_Range:0] = TS_X;  // error
// synopsys translate_off
        if ($time > 0)
          $display ("*** %m PCI Target State Machine Unknown %x at time %t",
                         Target_Next_State_MASTER_DATA_MORE[TS_Range:0], $time);
// synopsys translate_on
      end
    endcase
  end
endfunction

// NOTE: DON"T DEBUG USING THIS FUNCTION.  Use the full function at the bottom
//       of the file.  This is a subset, derived from the full State Machine.
// FRAME and IRDY are {0, 1}
function [TS_Range:0] Target_Next_State_MASTER_DATA_LAST;
  input  [TS_Range:0] Target_Present_State;
  input   Response_FIFO_has_Room;
  input   DELAYED_READ_FIFO_CONTAINS_DATA;
  input   Timeout_Forces_Disconnect;
  input   frame_in_prev;
  input   irdy_in_prev;
  input   frame_in_prev_prev;
  input   irdy_in_prev_prev;

  begin
    case (Target_Present_State[TS_Range:0])  // synopsys parallel_case
    default:
      begin
        Target_Next_State_MASTER_DATA_LAST[TS_Range:0] = TS_X;  // error
// synopsys translate_off
        if ($time > 0)
          $display ("*** %m PCI Target State Machine Unknown %x at time %t",
                         Target_Next_State_MASTER_DATA_LAST[TS_Range:0], $time);
// synopsys translate_on
      end
    endcase
  end
endfunction

// State Machine controlling the PCI Target.
//   Every clock, this State Machine transitions based on the LATCHED
//   versions of FRAME and IRDY.  At the same time, combinational logic
//   below has already sent out the NEXT info to the PCI bus.
//  (These two actions had better be consistent.)
// The way to think about this is that the State Machine reflects the
//   PRESENT state of the PCI wires.  When you are in the DEVSEL state,
//   Devsel is valid on the bus.
  reg    [TS_Range:0] PCI_Target_State;  // forward reference

// Assign the result to a variable for later use.
  wire   [TS_Range:0] PCI_Target_Next_State_MASTER_IDLE =
              Target_Next_State_MASTER_IDLE (
                PCI_Target_State[TS_Range:0],
                pci_response_fifo_room_available_meta,
                pci_delayed_read_fifo_data_available_meta,
                Target_Initial_Latency_Disconnect
                    | Target_Subsequent_Latency_Disconnect,
                pci_frame_in_prev,
                pci_irdy_in_prev,
                pci_frame_in_prev_prev,
                pci_irdy_in_prev_prev
              );

// Assign the result to a variable for later use.
  wire   [TS_Range:0] PCI_Target_Next_State_MASTER_WAIT =
              Target_Next_State_MASTER_WAIT (
                PCI_Target_State[TS_Range:0],
                pci_response_fifo_room_available_meta,
                pci_delayed_read_fifo_data_available_meta,
                Target_Initial_Latency_Disconnect
                    | Target_Subsequent_Latency_Disconnect,
                pci_frame_in_prev,
                pci_irdy_in_prev,
                pci_frame_in_prev_prev,
                pci_irdy_in_prev_prev
              );

// Assign the result to a variable for later use.
  wire   [TS_Range:0] PCI_Target_Next_State_MASTER_DATA_MORE =
              Target_Next_State_MASTER_DATA_MORE (
                PCI_Target_State[TS_Range:0],
                pci_response_fifo_room_available_meta,
                pci_delayed_read_fifo_data_available_meta,
                Target_Initial_Latency_Disconnect
                    | Target_Subsequent_Latency_Disconnect,
                pci_frame_in_prev,
                pci_irdy_in_prev,
                pci_frame_in_prev_prev,
                pci_irdy_in_prev_prev
              );

// Assign the result to a variable for later use.
  wire   [TS_Range:0] PCI_Target_Next_State_MASTER_DATA_LAST =
              Target_Next_State_MASTER_DATA_LAST (
                PCI_Target_State[TS_Range:0],
                pci_response_fifo_room_available_meta,
                pci_delayed_read_fifo_data_available_meta,
                Target_Initial_Latency_Disconnect
                    | Target_Subsequent_Latency_Disconnect,
                pci_frame_in_prev,
                pci_irdy_in_prev,
                pci_frame_in_prev_prev,
                pci_irdy_in_prev_prev
              );

// NOTE: WORKING: write using manually instantiated (?) fast MUX, then OR
  wire   [TS_Range:0] PCI_Target_Next_State_Partial_Functions =
             (({pci_frame_in_critical, pci_irdy_in_critical} == MASTER_IDLE)
                 ? PCI_Target_Next_State_MASTER_IDLE[TS_Range:0] : PCI_TARGET_IDLE_000)
           | (({pci_frame_in_critical, pci_irdy_in_critical} == MASTER_WAIT)
                 ? PCI_Target_Next_State_MASTER_WAIT[TS_Range:0] : PCI_TARGET_IDLE_000)
           | (({pci_frame_in_critical, pci_irdy_in_critical} == MASTER_DATA_MORE)
                 ? PCI_Target_Next_State_MASTER_DATA_MORE[TS_Range:0] : PCI_TARGET_IDLE_000)
           | (({pci_frame_in_critical, pci_irdy_in_critical} == MASTER_DATA_LAST)
                 ? PCI_Target_Next_State_MASTER_DATA_LAST[TS_Range:0] : PCI_TARGET_IDLE_000);

// synopsys translate_off
  wire   [TS_Range:0] PCI_Target_Next_State_Full_Function;  // forward declaration
// synopsys translate_on

// NOTE: Use Full Function for Debug, Partial Functions when satisfied.
`define USE_FULL_TARGET_FUNCTION_FOR_DEBUG
`ifdef USE_FULL_TARGET_FUNCTION_FOR_DEBUG
  wire   [TS_Range:0] PCI_Target_Next_State =
                            PCI_Target_Next_State_Full_Function[TS_Range:0];
`else  // USE_FULL_TARGET_FUNCTION_FOR_DEBUG
  wire   [TS_Range:0] PCI_Target_Next_State =
                            PCI_Target_Next_State_Partial_Functions[TS_Range:0];
`endif  // USE_FULL_TARGET_FUNCTION_FOR_DEBUG

// Actual State Machine includes async reset
  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
      PCI_Target_State[TS_Range:0] <= PCI_TARGET_IDLE_000;
    else if (pci_reset_comb == 1'b0)
      PCI_Target_State[TS_Range:0] <= PCI_Target_Next_State[TS_Range:0];
    else
      PCI_Target_State[TS_Range:0] <= TS_X;
  end

// Make delayed version, used for active release of DEVSEL, TRDY, and STOP.
  reg    [TS_Range:0] PCI_Target_Prev_State;

  always @(posedge pci_clk or posedge pci_reset_comb) // async reset!
  begin
    if (pci_reset_comb == 1'b1)
    begin
      PCI_Target_Prev_State[TS_Range:0] <= PCI_TARGET_IDLE_000;
      pci_frame_in_prev_prev <= 1'b0;
      pci_irdy_in_prev_prev <= 1'b0;
    end
    else if (pci_reset_comb == 1'b0)
    begin
      PCI_Target_Prev_State[TS_Range:0] <= PCI_Target_State[TS_Range:0];
      pci_frame_in_prev_prev <= pci_frame_in_prev;
      pci_irdy_in_prev_prev <= pci_irdy_in_prev;
    end
    else
    begin
      PCI_Target_Prev_State[TS_Range:0] <= TS_X;
      pci_frame_in_prev_prev <= 1'bX;
      pci_irdy_in_prev_prev <= 1'bX;
    end
  end

// Classify the Present State to make the terms below easier to understand.
  wire    Target_In_Idle_State =
                      (PCI_Target_State[TS_Range:0] == PCI_TARGET_IDLE_000);

// As quickly as possible, decide whether to present new Target Control Info
//   on Target Control bus, or to continue sending old data.  The state machine
//   needs to know what happened too, so it can prepare the Control info for
//   next time.
// NOTE: FRAME and IRDY are very late.  3 nSec before clock edge!
// NOTE: The DEVSEL_Next, TRDY_Next, and STOP_Next signals are latched in the
//       output pads in the IO pad module.

  wire   [2:0] PCI_Next_DEVSEL_Code = 3'h0;  // NOTE Working
  wire   [2:0] PCI_Next_TRDY_Code = 3'h0;  // NOTE: Working
  wire   [2:0] PCI_Next_STOP_Code = 3'h0;  // NOTE: Working

// NOTE: WORKING temporarily set values to OE signals to let the bus not be X's
  assign  target_got_parity_error = 1'b0;  // NOTE: WORKING
  assign  target_caused_serr = 1'b0;  // NOTE: WORKING
  assign  target_caused_abort = 1'b0;  // NOTE: WORKING

  assign  pci_target_par_out_oe_comb = 1'b0;  // NOTE: WORKING
  assign  pci_target_perr_out_oe_comb = 1'b0;  // NOTE: WORKING
  assign  pci_target_serr_out_oe_comb = 1'b0;  // NOTE: WORKING

  assign  Target_Force_AD_to_Data = 1'b0;  // NOTE: WORKING
  assign  Target_Exposes_Data_On_IRDY = 1'b0;  // NOTE: WORKING
  assign  Target_Forces_PERR = 1'b0;  // NOTE: WORKING

  assign  pci_delayed_read_fifo_data_unload = 1'b0;  // NOTE: WORKING

  assign  pci_config_write_data[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_ZERO;  // NOTE: WORKING
  assign  pci_config_address[PCI_BUS_DATA_RANGE:0] = 6'h00;  // NOTE: WORKING
  assign  pci_config_byte_enables[PCI_BUS_CBE_RANGE:0] = `PCI_BUS_CBE_ZERO;  // NOTE: WORKING
  assign  pci_config_write_req = 1'b0;  // NOTE: WORKING

  assign  pci_target_ad_out_oe_comb = 1'b0;  // NOTE: WORKING
  assign  pci_d_t_s_out_oe_comb = 1'b0;  // NOTE: WORKING
  assign  pci_response_fifo_data_load = 1'b0;  // NOTE: WORKING

  assign  master_to_target_status_unload = 1'b1;  // NOTE: WORKING.  Debugging Master

// Instantiate Configuration Registers.
pci_blue_config_regs pci_blue_config_regs (
  .pci_config_write_data      (pci_config_write_data[PCI_BUS_DATA_RANGE:0]),
  .pci_config_read_data       (pci_config_read_data[PCI_BUS_DATA_RANGE:0]),
  .pci_config_address         (pci_config_address[PCI_BUS_DATA_RANGE:0]),
  .pci_config_byte_enables    (pci_config_byte_enables[PCI_BUS_CBE_RANGE:0]),
  .pci_config_write_req       (pci_config_write_req),
// Indication that the reference is acceptable
  .PCI_Base_Address_Hit       (PCI_Base_Address_Hit),
// Signals from the Config Registers to enable features in the Master and Target
  .target_memory_enable       (target_memory_enable),
  .master_enable              (master_enable),
  .either_perr_enable         (either_perr_enable),
  .either_serr_enable         (either_serr_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_latency_value       (master_latency_value[7:0]),
// Signals from the Master or the Target to set bits in the Status Register
  .master_caused_parity_error (master_caused_parity_error),
  .target_caused_abort        (target_caused_abort),
  .master_got_target_abort    (master_got_target_abort),
  .master_caused_master_abort (master_caused_master_abort),
  .either_caused_serr         (either_caused_serr),
  .either_got_parity_error    (either_got_parity_error),
// Courtesy indication that PCI Interface Config Register contains an error indication
  .target_config_reg_signals_some_error (target_config_reg_signals_some_error),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (pci_reset_comb)
);

// synopsys translate_off

// Debugging and correctness checking stuff below.  NOT used in synthesized design.

function [TS_Range:0] Target_Next_State;
  input  [TS_Range:0] Target_Present_State;

  input   frame_in_critical;
  input   irdy_in_critical;
  input   frame_in_prev;
  input   irdy_in_prev;
  input   frame_in_prev_prev;
  input   irdy_in_prev_prev;

  input   config_ref;
  input   read_ref;

  input   invalid_command;
  input   mem_io_ref;

  input   mem_io_address_match;

  input   Response_FIFO_has_Two_Words_Of_Room;

  input  [1:0] delayed_read_state;
  input   delayed_address_match;

  input   DELAYED_READ_FIFO_CONTAINS_DATA;
  input   Timeout_Forces_Disconnect;


  input   delayed_data_available;
  input   target_abort;
  input   target_retry;
  input   target_last_data;
  input   near_bank_end;

  begin
// synopsys translate_off
    if (   ( $time > 0)
         & (   ((frame_in_critical ^ frame_in_critical) === 1'bX)
             | ((irdy_in_critical ^ irdy_in_critical) === 1'bX)))
    begin
      Target_Next_State[TS_Range:0] = TS_X;  // error
      $display ("*** %m PCI Target State Machine FRAME, IRDY Unknown %x %x at time %t",
                  frame_in_critical, irdy_in_critical, $time);
    end
    else
// synopsys translate_on

    case (Target_Present_State[TS_Range:0])  // synopsys parallel_case
// The Target can get an Address Parity Error.  This is when the Address
//   plus Command has wrong parity during an ordinary Address Phase, or
//   during either phase of a Dual Address cycle.
// The Target will respond as if no parity error had occurred.
// It is the responsibility of the Host to notice the Parity Error
//   and to avoid doing any activity with fatal side effects.
// The Host Interface might Target Abort any Reads, and ignore any writes.
// See the PCI Local Bus Spec Revision 2.2 section 3.7.3 for details.

    PCI_TARGET_IDLE_000:
      begin
        if (   ({frame_in_prev, irdy_in_prev} == MASTER_WAIT)  // starting transfer
             & (   ({frame_in_prev_prev, irdy_in_prev_prev} == MASTER_IDLE)  // idle previously
                 | ({frame_in_prev_prev, irdy_in_prev_prev} == MASTER_DATA_LAST)) )  // finishing previously
        begin
          if (config_ref == 1'b1)  // Config References done without telling Target
          begin
            if (read_ref == 1'b1)
            begin
              Target_Next_State[TS_Range:0] = PCI_TARGET_CONFIG_READ_WAIT_100;
            end
            else
            begin
              Target_Next_State[TS_Range:0] = PCI_TARGET_CONFIG_WRITE_WAIT_100;
            end
          end
          else if ((config_ref == 1'b0) & (invalid_command == 1'b1))  // ignore if unrecognized command
          begin
            Target_Next_State[TS_Range:0] = PCI_TARGET_NOT_ME_000;
          end
          else if (   (config_ref == 1'b0) & (invalid_command == 1'b0)
                    & (mem_io_ref == 1'b1) )
          begin
            if (mem_io_address_match == 1'b0)
            begin  // ignore if no match possible
              Target_Next_State[TS_Range:0] = PCI_TARGET_NOT_ME_000;
            end
            else if (   (mem_io_address_match == 1'b1)
                      & (Response_FIFO_has_Two_Words_Of_Room == 1'b0) )
            begin  // must be match, so stall if impossible to send data to Target
              Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_RETRY_101;
            end
            else if (   (mem_io_address_match == 1'b1)
                      & (Response_FIFO_has_Two_Words_Of_Room == 1'b1)
                      & (read_ref == 1'b1) )
            begin  // its a read

              if ((delayed_read_state[1:0] == DELAYED_READ_NOT_ACTIVE))
              begin  // start delayed read immediately
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_RETRY_101;
              end
              else if (   (delayed_read_state[1:0] != DELAYED_READ_NOT_ACTIVE)
                        & (delayed_address_match == 1'b0) )
              begin  // defer other reads until delayed read done
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_RETRY_101;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_FLUSH)
                        & (delayed_address_match == 1'b1) )
              begin  // defer read until flush done
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_RETRY_101;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_FLUSH_DONE)
                        & (delayed_address_match == 1'b1) )
              begin  // start delayed read immediately
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_RETRY_101;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_DATA_WAIT)
                        & (delayed_address_match == 1'b1)
                        & (delayed_data_available == 1'b0) )
              begin  // no data available yet.  Wait for a while, look again
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_WAIT_100;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_DATA_WAIT)
                        & (delayed_address_match == 1'b1)
                        & (delayed_data_available == 1'b1)
                        & (target_abort == 1'b1) )
              begin  // Host says do Target Abort
                Target_Next_State[TS_Range:0] = PCI_TARGET_READ_ABORT_FIRST_100;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_DATA_WAIT)
                        & (delayed_address_match == 1'b1)
                        & (delayed_data_available == 1'b1)
                        & (target_retry == 1'b1) )
              begin  // Host says do Target Abort
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_RETRY_101;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_DATA_WAIT)
                        & (delayed_address_match == 1'b1)
                        & (delayed_data_available == 1'b1)
                        & (target_last_data == 1'b1) )
              begin  // Host says do Last Data now
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_DATA_STOP_111;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_DATA_WAIT)
                        & (delayed_address_match == 1'b1)
                        & (delayed_data_available == 1'b1)
                        & (target_last_data == 1'b0)
                        & (near_bank_end == 1'b1) )
              begin  // Host says do more Data, but getting close to memory bank boundry
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_DATA_STOP_111;
              end
              else if (   (delayed_read_state[1:0] == DELAYED_READ_DATA_WAIT)
                        & (delayed_address_match == 1'b1)
                        & (delayed_data_available == 1'b1)
                        & (target_last_data == 1'b0)
                        & (near_bank_end == 1'b0) )
              begin  // Host says do more Data
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_READ_DATA_110;
              end
              else
              begin
                Target_Next_State[TS_Range:0] = PCI_TARGET_IDLE_000;
  $display ("something");
              end
            end
            else if (   (mem_io_address_match == 1'b1)
                      & (Response_FIFO_has_Two_Words_Of_Room == 1'b1)
                      & (read_ref == 1'b0))
            begin  // its a write
              if (near_bank_end == 1'b1)
              begin
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_WRITE_DATA_STOP_111;
              end
              else if (near_bank_end == 1'b0)
              begin
                Target_Next_State[TS_Range:0] = PCI_TARGET_MEMORY_WRITE_DATA_110;
              end
              else
              begin
                Target_Next_State[TS_Range:0] = PCI_TARGET_IDLE_000;
  $display ("something");
              end
            end
            else  // error
            begin
              Target_Next_State[TS_Range:0] = PCI_TARGET_IDLE_000;
  $display ("something");
            end
          end
        end
      end

    PCI_TARGET_NOT_ME_000:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_CONFIG_READ_WAIT_100:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_CONFIG_READ_DATA_110:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_READ_WAIT_100:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_READ_DATA_110:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_READ_DATA_STOP_111:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_READ_RETRY_101:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_READ_ABORT_FIRST_100:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_READ_ABORT_SECOND_001:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_CONFIG_WRITE_WAIT_100:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_CONFIG_WRITE_DATA_110:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_WRITE_WAIT_100:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_WRITE_DATA_110:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_WRITE_DATA_STOP_111:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_MEMORY_WRITE_RETRY_101:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_WRITE_ABORT_FIRST_100:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    PCI_TARGET_WRITE_ABORT_SECOND_001:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // NOTE: WORKING
      end
    default:
      begin
        Target_Next_State[TS_Range:0] = TS_X;  // error// synopsys translate_off
// synopsys translate_off
        if ($time > 0)
          $display ("*** %m PCI Target State Machine Unknown %x at time %t",
                         Target_Next_State[TS_Range:0], $time);
// synopsys translate_on
      end
    endcase
  end
endfunction

  assign  PCI_Target_Next_State_Full_Function[TS_Range:0] =
              Target_Next_State (
                PCI_Target_State[TS_Range:0],
                pci_response_fifo_room_available_meta,
                pci_delayed_read_fifo_data_available_meta,
                Target_Initial_Latency_Disconnect
                    | Target_Subsequent_Latency_Disconnect,
                pci_frame_in_critical,
                pci_irdy_in_critical,
                pci_frame_in_prev,
                pci_irdy_in_prev,
                pci_frame_in_prev_prev,
                pci_irdy_in_prev_prev,
                address_data_parity,
                pci_par_in_critical,
                pci_config_ref,
                pci_mem_io_ref,
                pci_invalid_command
              );

  always @(posedge pci_clk)
  begin
    if (     PCI_Target_Next_State_Full_Function[TS_Range:0]
         !== PCI_Target_Next_State_Partial_Functions [TS_Range:0])
      $display ("*** %m Partial Target Functions don't match Full Target Function");
  end


`ifdef CALL_OUT_TARGET_STATE_TRANSITIONS
// Look inside the target module and try to call out transition names.
  parameter NUM_STATES = 50;  // NOTE: WORKING:
  reg    [NUM_STATES:1] transitions_seen;

task initialize_transition_table;
  integer i;
  begin
    for (i = 1; i <= NUM_STATES; i = i + 1)
    begin
      transitions_seen[i] = 1'b0;
    end
//    transitions_seen[4] = 1'b1;
  end
endtask

task call_out_transition;
  input i;
  integer i;
  begin
    if ((i >= 1) & (i <= NUM_STATES))
    begin
      $display ("Target transition %d seen at %t", i, $time);
      transitions_seen[i] = 1'b1;
    end
    else
    begin
      $display ("*** bogus Target transition %d seen at %t", i, $time);
    end
  end
endtask

task report_missing_transitions;
  integer i, j;
  begin
  $display ("calling out Target transitions which were not yet exercised");
    j = 0;
    for (i = 1; i <= NUM_STATES; i = i + 1)
    begin
      if (transitions_seen[i] == 1'b0)
      begin
        $display ("Target transition %d not seen", i);
        j = j + 1;
      end
    end
    $display ("%d Target transitions not seen", j);
  end
endtask

  initial initialize_transition_table;

  reg     prev_fifo_contains_address;
  reg     prev_fifo_contains_data_more, prev_fifo_contains_data_two_more;
  reg     prev_fifo_contains_data_last, prev_timeout_forces_disconnect;
  reg     prev_back_to_back_possible, prev_doing_config_reference;
  reg     prev_bus_available, prev_config_reference;
  reg     prev_master_retry_write;

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
    prev_back_to_back_possible <= master_fast_b2b_en;
    prev_doing_config_reference <= Master_Doing_Config_Reference;
    prev_master_retry_write <= Master_Retry_Write;
    if (   (PCI_Target_Prev_State[4:0] == PCI_TARGET_IDLE_000)
         & (prev_bus_available == 1'b1)
         & (prev_fifo_contains_address == 1'b0) )
      call_out_transition (1);
  end
// synopsys translate_on
`endif  // CALL_OUT_TARGET_STATE_TRANSITIONS
endmodule

