//===========================================================================
// $Id: pci_blue_target.v,v 1.15 2001-07-05 02:42:59 bbeaver Exp $
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
  pci_frame_in_prev,   pci_frame_in_comb,
  pci_irdy_in_prev,    pci_irdy_in_comb,
  pci_devsel_out_next, pci_d_t_s_out_oe_comb,
  pci_trdy_out_next,   pci_stop_out_next,
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

// Signals driven to control the external PCI interface
  input  [`PCI_BUS_DATA_RANGE] pci_ad_in_prev;
  output [`PCI_BUS_DATA_RANGE] pci_target_ad_out_next;
  output  pci_target_ad_en_next;
  output  pci_target_ad_out_oe_comb;
  input   pci_idsel_in_prev;
  input  [`PCI_BUS_CBE_RANGE] pci_cbe_l_in_prev;
  input   pci_par_in_prev;
  input   pci_par_in_comb;
  output  pci_target_par_out_next;
  output  pci_target_par_out_oe_comb;
  input   pci_frame_in_prev;
  input   pci_frame_in_comb;
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
  output [`PCI_BUS_CBE_RANGE] pci_response_fifo_type;
  output [`PCI_BUS_CBE_RANGE] pci_response_fifo_cbe;
  output [`PCI_BUS_DATA_RANGE] pci_response_fifo_data;
  input   pci_response_fifo_room_available_meta;
  output  pci_response_fifo_data_load;
  input   pci_response_fifo_error;
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  input  [2:0] pci_delayed_read_fifo_type;
  input  [`PCI_BUS_DATA_RANGE] pci_delayed_read_fifo_data;
  input   pci_delayed_read_fifo_data_available_meta;
  output  pci_delayed_read_fifo_data_unload;
  input   pci_delayed_read_fifo_error;
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  input  [2:0] master_to_target_status_type;
  input  [`PCI_BUS_CBE_RANGE] master_to_target_status_cbe;
  input  [`PCI_BUS_DATA_RANGE] master_to_target_status_data;
  input   master_to_target_status_flush;
  input   master_to_target_status_available;
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

// Signals driven to control the external PCI interface
  wire   [`PCI_BUS_DATA_RANGE] pci_config_write_data;
  wire   [`PCI_BUS_DATA_RANGE] pci_config_read_data;
  wire   [7:2] pci_config_address;
  wire   [`PCI_BUS_CBE_RANGE] pci_config_byte_enables;
  wire    pci_config_write_req;

// Signals from the Config Registers to enable features in the Master and Target
  wire    target_memory_enable;
  wire    target_perr_enable, either_perr_enable;
  wire    target_serr_enable, either_serr_enable;
  wire   [`PCI_BASE_ADDR0_MATCH_RANGE] base_register_0;
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
  wire   [`PCI_BASE_ADDR1_MATCH_RANGE] base_register_1;
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE

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

// Address Compare logic to discover whether a non-config reference is for
// this PCI controller.
// NOTE: The number of valid MSB bits in the Base Address Registers, and the
//       number of Base Registers, is set in the file pci_blue_options.vh

// NOTE: WORKING need to take into account type, special, config refs
  wire    PCI_Base_Address_Hit =
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
                          (pci_ad_in_prev[`PCI_BASE_ADDR1_MATCH_RANGE]
                                == base_register_1[`PCI_BASE_ADDR1_MATCH_RANGE])
                        |
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
                          (pci_ad_in_prev[`PCI_BASE_ADDR0_MATCH_RANGE]
                                == base_register_0[`PCI_BASE_ADDR0_MATCH_RANGE]);

// Target Initial Latency Counter.  Must respond within 16 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.1.1 for details.
// NOTE: It would be better to ALWAYS make every Memory read into a Delayed Read!

// Target Subsequent Latency Counter.  Must make progress within 8 Bus Clocks.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.1.2 for details.

  reg    [2:0] Target_Subsequent_Latency_Counter;
  reg     Read_Subsequent_Latency_Disconnect;

  always @(posedge pci_clk)
  begin
    if (pci_reset_comb)
    begin
      Target_Subsequent_Latency_Counter[2:0] <= 3'h0;
      Read_Subsequent_Latency_Disconnect <= 1'b0;
    end
  end

// Keep track of the present PCI Address, so the Target can respond
// to the Delayed Read request when it is issued.
// Configuration References will NOT result in Delayed Reads.
// All other reads will become Delayed Reads, and a Read can be
// further delayed if data does not arrive soon enough in the
// middle of a Burst.
// See the PCI Local Bus Spec Revision 2.2 section 3.5.1.1 and
// 3.5.1.2 for details.
// The bottom 2 bits of a PCI Address have special meaning to the
// PCI Master and PCI Target.  See the PCI Local Bus Spec
// Revision 2.2 section 3.2.2.1 and 3.2.2.2 for details.

  reg    [`PCI_BUS_DATA_RANGE] Target_Delayed_Read_Address;
  reg    [`PCI_BUS_CBE_RANGE] Target_Delayed_Read_Command;
  reg    [`PCI_BUS_CBE_RANGE] Target_Delayed_Read_Byte_Strobes;
  reg     Target_Delayed_Read_Address_Parity;
  reg     Grab_Target_Address, Prev_Grab_Target_Address, Inc_Target_Address;

  always @(posedge pci_clk)
  begin
    if (Grab_Target_Address == 1'b1)
    begin
      Target_Delayed_Read_Address[`PCI_BUS_DATA_RANGE] <= pci_ad_in_prev[`PCI_BUS_DATA_RANGE];
      Target_Delayed_Read_Command[`PCI_BUS_CBE_RANGE] <= pci_cbe_l_in_prev[`PCI_BUS_CBE_RANGE];
      Target_Delayed_Read_Address_Parity <= 1'b0;  // NOTE WORKING
    end
    else
    begin
      if (Inc_Target_Address == 1'b1)
      begin
        Target_Delayed_Read_Address[`PCI_BUS_DATA_RANGE] <=
                          Target_Delayed_Read_Address[`PCI_BUS_DATA_RANGE]
                        + 32'h00000004;
      end
      else
      begin
        Target_Delayed_Read_Address[`PCI_BUS_DATA_RANGE] <=
                               Target_Delayed_Read_Address[`PCI_BUS_DATA_RANGE];
      end
      Target_Delayed_Read_Command[`PCI_BUS_CBE_RANGE] <=
                               Target_Delayed_Read_Command[`PCI_BUS_CBE_RANGE];
    end
    Prev_Grab_Target_Address <= Grab_Target_Address;
    if ((Prev_Grab_Target_Address == 1'b1) || (Inc_Target_Address == 1'b1))
    begin
      Target_Delayed_Read_Byte_Strobes[`PCI_BUS_CBE_RANGE] <=
                               pci_cbe_l_in_prev[`PCI_BUS_CBE_RANGE];
    end
    else
    begin
      Target_Delayed_Read_Byte_Strobes[`PCI_BUS_CBE_RANGE] <=
                               Target_Delayed_Read_Byte_Strobes[`PCI_BUS_CBE_RANGE];
    end
  end

// Delayed Read Discard Counter
// See the PCI Local Bus Spec Revision 2.2 section 3.3.3.3.3 for details.

  reg    [14:0] Delayed_Read_Discard_Counter;
  reg     Delayed_Read_Discard_Now;

  always @(posedge pci_clk)
  begin
    if (pci_reset_comb)
    begin
      Delayed_Read_Discard_Counter[14:0] <= 15'h7FFF;
      Delayed_Read_Discard_Now <= 1'b0;
    end
    else if (Grab_Target_Address)
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

  reg     Delayed_Read_In_Progress;

  always @(posedge pci_clk or posedge pci_reset_comb)
  begin
    if (pci_reset_comb)
    begin
      Delayed_Read_In_Progress <= 1'b0;
    end
    else
    begin  // NOTE: WORKING
      if (Delayed_Read_In_Progress && Delayed_Read_Discard_Now)
      begin
        Delayed_Read_In_Progress <= 1'b0;
      end
      else
      begin
        Delayed_Read_In_Progress <= 1'b0;  // NOTE WORKING
      end
    end
  end

// Address Compare Logic to discover if a Read is being done to the same
// address with the same command and Byte Strobes as the present Delayed Read.

  wire    Delayed_Read_Address_Match = Delayed_Read_In_Progress
             & (Target_Delayed_Read_Address[`PCI_BUS_DATA_RANGE] ==
                                      pci_ad_in_prev[`PCI_BUS_DATA_RANGE])
             & (Target_Delayed_Read_Command[`PCI_BUS_CBE_RANGE] ==
                                      pci_cbe_l_in_prev[`PCI_BUS_CBE_RANGE])
             & (Target_Delayed_Read_Address_Parity == 1'b0)  // NOTE: WORKING
             & (Target_Delayed_Read_Byte_Strobes[`PCI_BUS_CBE_RANGE] ==
                                      pci_cbe_l_in_prev[`PCI_BUS_CBE_RANGE]);

// Address Compare logic to discover whether a Write has been done to data
// which is in the Delayed Read Prefetch Buffer.
// Assume here that the Prefetch Buffer contains 16 words of 8 bytes, or 128 bytes.
// NOTE: This will have to change if the FIFO were made longer, but is safe
//       if the Prefetch FIFO is 16 entries of 64 bits each.
// See the PCI Local Bus Spec Revision 2.2 section 3.2.5 for details.

  wire    Delayed_Read_Write_Collision =
                (pci_ad_in_prev[31:7] ==  Target_Delayed_Read_Address[31:7])
              | (pci_ad_in_prev[31:7] == (Target_Delayed_Read_Address[31:7]
                                          + 25'h0000001) );

// The Target State Machine as described in Appendix B.
// No Lock State Machine is implemented.
// This design supports Medium Decode.  Fast Decode is not supported.
//
// Here is my interpretation of the Target State Machine:
//
// The Target is in one of 4 states when transferring data:
// 1) Waiting,
// 2) Transferring data with more to come,
// 3) Transferring the last Data item.
// 4) Stopping a transfer
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
// The functions will be implemented as a 4-1 MUX using FRAME and IRDY
//   as the selection variables.
// The inputs to the DEVSEL, TRDY, and STOP MUX's will be decided based
//   on the state the Target is in, and also on the contents of the
//   Delayed Read Data FIFO.
// NOTE WORKING THIS NEXT MAY BE WRONG
// NOTE: that for both FRAME and IRDY, there are 5 possible functions of
//   TRDY and STOP.  Both output bits might be all 0's, all 1's, and
//   each has 3 functions which are not all 0's nor all 1's.
// NOTE: These extremely timing critical functions will each be implemented
//   as a single CLB in a Xilinx chip, with a 3-bit Function Selection
//   paramater.  The 3 bits plus FRAME plus IRDY use up a 5-input LUT.
//
// The functions are as follows:
//    Function Sel [2:0] FRAME  IRDY   ->  TRDY  STOP
//                  0XX    X     X          0     0
//
//                  100    X     X          1     1
//
// Master Wait      101    1     0          1     0
// Master Data      101    1     1          1     0
// Master Last Data 101    0     1          1     0
//
// Master Wait      110    1     0          1     1
// Master Data      110    1     1          1     0
// Master Last Data 110    0     1          0     1
//
// Master Wait      111    1     0          1     1
// Master Data      111    1     1          0     0
// Master Last Data 111    0     1          0     0
//
// For each state, use the function:        F(TRDY) F(STOP)
//    TARGET_IDLE,        FIFO Empty          000     000 (no FRAME, IRDY)
//    TARGET_IDLE         FIFO Address        100     000 (Always FRAME)
//    TARGET_ADDR         FIFO Don't care     100     000 (Always FRAME)
//    TARGET_NOT_ME       FIFO Don't care     100     000 (Always FRAME)
//    TARGET_WAIT,        FIFO Empty          101     101 (FRAME unless DRA)
//    TARGET_WAIT,        FIFO non-Last Data  110     100
//    TARGET_WAIT,        FIFO Last Data      000     100
//    TARGET_WAIT,        FIFO Abort          000     100
//    TARGET_DATA_MORE,   FIFO Empty          110     110
//    TARGET_DATA_MORE,   FIFO non-Last Data  110     100
//    TARGET_DATA_MORE,   FIFO Last Data      111     100
//    TARGET_DATA_MORE,   FIFO Abort          111     100
//    TARGET_DATA_LAST,   FIFO Empty          000     111 (or if no Fast Back-to-Back)
//    TARGET_DATA_LAST,   FIFO Address        100     000 (and if Fast Back-to-Back)
//    TARGET_STOP,        FIFO Empty          000     000 (or if no Fast Back-to-Back)
//    TARGET_STOP,        FIFO Address        100     000 (and if Fast Back-to-Back)

  parameter PCI_TARGET_IDLE      = 8'b00000001;  // Target in IDLE state
  parameter PCI_TARGET_ADDR      = 8'b00000010;  // Target decodes Address
  parameter PCI_TARGET_NOT_ME    = 8'b00000100;  // Some Other device is addressed
  parameter PCI_TARGET_WAIT      = 8'b00001000;  // Waiting for Target Data
  parameter PCI_TARGET_DATA_MORE = 8'b00010000;  // Target Transfers Data
  parameter PCI_TARGET_DATA_LAST = 8'b00100000;  // Target Transfers Last Data
  parameter PCI_TARGET_ABORT     = 8'b01000000;  // Target waits till Frame goes away
  parameter PCI_TARGET_STOP      = 8'b10000000;  // Target waits till Frame goes away
  reg    [7:0] PCI_Target_State;

// These correspond to      {frame, irdy}
  parameter MASTER_IDLE      = 2'b10;
  parameter MASTER_DATA_MORE = 2'b11;
  parameter MASTER_DATA_LAST = 2'b01;

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
      PCI_Target_State[7:0] <= PCI_TARGET_IDLE;
    end
    else
    begin
      case (PCI_Target_State[7:0])
      PCI_TARGET_IDLE:
        begin
        end
      PCI_TARGET_ADDR:
        begin
        end
      PCI_TARGET_NOT_ME:
        begin
        end
      PCI_TARGET_WAIT:
        begin
        end
      PCI_TARGET_DATA_MORE:
        begin
        end
      PCI_TARGET_DATA_LAST:
        begin
        end
      PCI_TARGET_STOP:
        begin
        end
      default:
        begin
          PCI_Target_State[7:0] <= PCI_TARGET_IDLE;  // error
// synopsys translate_off
          $display ("PCI Target State Machine Unknown %x at time %t",
                           PCI_Target_State[7:0], $time);
// synopsys translate_on
        end
      endcase
    end
  end

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

  assign  pci_config_write_data[`PCI_BUS_DATA_RANGE] = `PCI_BUS_DATA_ZERO;  // NOTE: WORKING
  assign  pci_config_address[7:2] = 6'h00;  // NOTE: WORKING
  assign  pci_config_byte_enables[`PCI_BUS_CBE_RANGE] = `PCI_BUS_CBE_ZERO;  // NOTE: WORKING
  assign  pci_config_write_req = 1'b0;  // NOTE: WORKING

  assign  pci_target_ad_out_oe_comb = 1'b0;  // NOTE: WORKING
  assign  pci_d_t_s_out_oe_comb = 1'b0;  // NOTE: WORKING
  assign  pci_response_fifo_data_load = 1'b0;  // NOTE: WORKING

  assign  master_to_target_status_unload = 1'b1;  // NOTE: WORKING.  Debugging Master

pci_critical_next_devsel pci_critical_next_devsel (
  .PCI_Next_DEVSEL_Code       (PCI_Next_DEVSEL_Code[2:0]),
  .pci_frame_in_comb          (pci_frame_in_comb),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_devsel_out_next        (pci_devsel_out_next)
);

pci_critical_next_trdy pci_critical_next_Trdy (
  .PCI_Next_TRDY_Code         (PCI_Next_TRDY_Code[2:0]),
  .pci_frame_in_comb          (pci_frame_in_comb),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_trdy_out_next          (pci_trdy_out_next)
);

pci_critical_next_stop pci_critical_next_stop (
  .PCI_Next_STOP_Code         (PCI_Next_STOP_Code[2:0]),
  .pci_frame_in_comb          (pci_frame_in_comb),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_stop_out_next          (pci_stop_out_next)
);

// Instantiate Configuration Registers.
pci_blue_config_regs pci_blue_config_regs (
  .pci_config_write_data      (pci_config_write_data[`PCI_BUS_DATA_RANGE]),
  .pci_config_read_data       (pci_config_read_data[`PCI_BUS_DATA_RANGE]),
  .pci_config_address         (pci_config_address[7:2]),
  .pci_config_byte_enables    (pci_config_byte_enables[`PCI_BUS_CBE_RANGE]),
  .pci_config_write_req       (pci_config_write_req),
// Signals from the Config Registers to enable features in the Master and Target
  .target_memory_enable       (target_memory_enable),
  .master_enable              (master_enable),
  .either_perr_enable         (either_perr_enable),
  .either_serr_enable         (either_serr_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_latency_value       (master_latency_value[7:0]),
  .base_register_0            (base_register_0[`PCI_BASE_ADDR0_MATCH_RANGE]),
`ifdef PCI_BASE_ADDR1_MATCH_ENABLE
  .base_register_1            (base_register_1[`PCI_BASE_ADDR1_MATCH_RANGE]),
`endif  // PCI_BASE_ADDR1_MATCH_ENABLE
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
endmodule

