//===========================================================================
// $Id: pci_blue_fifos.v,v 1.9 2001-07-03 09:20:53 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The Request, Response, and Delayed Read Data FIFOs.
//           These modules instantiate the Fifo Flag module to keep track
//           of Fifo Full/Empty, and the FIFO storage.
//           The size of the Fifos can be 3, 5, 7, or 15 elements,
//           selected at compile time by options in pci_blue_options.vh.
//           These FIFOs can be implemented as flops followed by Muxes
//           or as true dual-port SRAMs, again selected by options.
//           This module instantiates the FIFOs bit-by-bit.  If custom-fit
//           SRAMs are available, they will have to be explicitly
//           instantiated in this module.
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
// NOTE:  This module implements the FIFOs used to communicate between the
//          Host and the PCI Controller.  In normal operation, one side
//          writes into the FIFO and the other reads out of it.  The two
//          references happen asynchronously.
//
// NOTE:  The Host interface operates on one clock, and the PCI Controller
//          operates on another.  Either or both of the clocks can stop
//          without warning.
//
// NOTE:  Both the Write Port and the Read Port are synchronous.  They latch
//          their address and enable signals, and in the case of the Write
//          port the Write Data, on the rising edge of the write clock.
//          The Read Data is available (hopefully) before the next clock.
//
// NOTE:  These FIFOs are guarded by Flags.  The Flags are used so that the
//          Reader of the FIFO does not read an entry in the FIFO which has
//          just been written.  The Flags have the correct pipeline delay
//          to ensure that the data in a particular FIFO location is written
//          at least one whole clock of the FASTER of the two interface clocks.
//
// NOTE:  These FIFOs are going to be used ina PCI environment.  The 66 MHz
//          PCI spec says that the IRSY and TRDY signals will be valid at
//          worst case 3 nSec before the rising edge of the external PCI
//          Clock.  In order to let these FIFOs use this very late signal
//          to control their loading and unloading, the FIFOs have extra
//          buffering.  A single Flip-Flop will be used to indicate that
//          empty space or data is available in the FIFO.
//          The FIFO Flag module will only look at this single Flop to
//          decide whether to load or unload the FIFO.  The PCI State Machine
//          will also look at this single Flop to decide whether to allow
//          the state sequence to progress.
//          The extra area used by the flops needed to support this idea
//          is discouraging.  However, time seems more precious than area.
//
// NOTE:  The guarantee that data always be valid before it is read is done
//          one of 2 ways.
//        1) The Writer writes the data before it writes the flag.
//        2) The Reader waits one clock after the flag is seen before reading.
//        Since the PCI Interface Clock is expected to be slower than the
//          Host clock, the PCI Interface should be operated in a mode which
//          makes transfers as fast as possible.
//        For transfers from the PCI Interface to the Processor, this would seem
//          to be the case when the PCI Interface writes both data and flags the
//          same clock, and when the Processor watches the Data Available Flag,
//          and only uses the data one clock AFTER it is marked available.
//        For transfers from the Processor to the PIC interface, this would seem
//          to be the case then the Processor first writes data, then writes the
//          Data Available Flag,   The PCI interface watches the Data Available
//          Flag, and when it is valid the data can be used the next clock.
//
// NOTE:  The Read Port of the FIFO on the Processor side can be disabled.  If
//          the underlying SRAM supports a power-down mode, this will result in
//          reduced power consumption.
//        Since the PCI side of the interface wants data to be available the same
//          clock the flag becomes valid, the PCI interface cannot disable the
//          read port.  It is expected to be the slow port, so it will be the
//          low power port.
//
// NOTE:  For details about the special considerations the Flag module has
//          with respect to synchronization, and the care needed to make
//          constraints which ensure adequate settling time to avoid
//          metastability, see the NOTES in the pci_fifo_flags module.
//
// NOTE:  In order to make it easier to remember how to use these FIFOs, the
//          configuration of the FIFOs will be set by a single MODE variable.
//        MODE 0:  Write Data written at the same time as the Write Flag.
//                 Read Flags and Data read constantly.
//                 This mode would be fine for any purpose if the Write and
//                   Read clocks were the same clock.
//                 This mode should not be used if an SRAM is used for FIFO
//                   storage, because the Read Flag may indicate Data when
//                   the SRAM is not ready to deliver it if clocks are different.
//                 This mode would be fine if Flops are used for FIFO Storage,
//                   however care must be taken to make sure that the Data
//                   Available signal has plenty of time to settle.
//        MODE 1:  Write Data written one clock before Write Flag.
//                 Read Flags and Data read constantly.
//                 This mode is fine if an SRAM is used for FIFO storage.
//                 Because the SRAM is read constantly, more power is used
//                   than the minimum.  This could be used when the Read port
//                   is on the low-clock-frequency side of the PCI interface.
//                 This mode would be wasteful of clock cycles if Flops are used
//                   for FIFO Storage.
//                 Care must still be taken to make sure that the Data Available
//                   signal has plenty of time to settle.
//        MODE 2:  Write Data written at the same time as the Write Flag.
//                 Read Flags read, and when set causes start of Data read.
//                 This mode is fine if an SRAM is used for FIFO storage.
//                   Because the SRAM is read only ocasionally, power is reduced.
//                   This could be used when the Read port is on the
//                   high-clock-frequency side of the PCI interface.
//                 This mode would be wasteful of clock cycles if Flops are used
//                   for FIFO Storage.
//                 Care must still be taken to make sure that the Data Available
//                   signal has plenty of time to settle.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

// Verilog module used to implement the 39-bit-wide Host Request FIFO
// The Read Port is on the PCI side, so it gets the extra buffering needed
// to make the unload activity depend on a single flop of state.
module pci_fifo_storage_request (
  reset_flags_async,
  fifo_mode,
  write_clk, write_sync_clk,
  write_room_available_meta,  // NOTE Needs extra settling time to avoid metastability
  write_submit,
  write_data,
  write_error,
  read_clk, read_sync_clk,
  read_data_available_meta,  // NOTE Needs extra settling time to avoid metastability
  read_two_words_available_meta,  // NOTE Needs extra settling time to avoid metastability
  read_remove,               // NOTE read_remove is VERY LATE
  read_data,
  read_error
);
  input   reset_flags_async;
  input  [1:0] fifo_mode;
  input   write_clk, write_sync_clk;
  output  write_room_available_meta;  // NOTE Needs extra settling time to avoid metastability
  input   write_submit;
  input  [38:0] write_data;
  output  write_error;
  input   read_clk, read_sync_clk;
  output  read_data_available_meta;  // NOTE Needs extra settling time to avoid metastability
  output  read_two_words_available_meta;  // NOTE Needs extra settling time to avoid metastability
  input   read_remove;               // NOTE read_remove is VERY LATE
  output [38:0] read_data;
  output  read_error;

  wire    double_sync_read_full_flag_const = 1'b0;
  wire    write_data_before_flag_const = (fifo_mode[1:0] == 2'b01);
  wire    read_flag_before_data_const = (fifo_mode[1:0] == 2'b10);

  wire   [3:0] write_address;
  wire   [3:0] read_address;
  wire    write_capture_data, read_enable;

pci_blue_fifo_flags pci_fifo_flags_request (
  .reset_flags_async          (reset_flags_async),
  .double_sync_read_full_flag_const   (double_sync_read_full_flag_const),
  .write_data_before_flag_const       (write_data_before_flag_const),
  .write_clk                  (write_clk),
  .write_sync_clk             (write_sync_clk),
  .write_submit               (write_submit),
  .write_capture_data         (write_capture_data),
  .write_room_available_meta  (write_room_available_meta),
  .write_address              (write_address[3:0]),
  .write_error                (write_error),
  .read_flag_before_data_const        (read_flag_before_data_const),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_sync_clk),
  .read_remove                (read_remove),
  .read_enable                (read_enable),
  .read_data_available_meta   (read_data_available_meta),
  .read_two_words_available_meta (read_two_words_available_meta),
  .read_address               (read_address[3:0]),
  .read_error                 (read_error)
);

// Note manually instantiate custom sized SRAMs here, if available.
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_7_0 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[7:0]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[7:0])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_15_8 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[15:8]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[15:8])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_23_16 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[23:16]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[23:16])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_31_24 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[31:24]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[31:24])
);
pci_fifo_storage_Nx4 pci_fifo_storage_Nx4_35_32 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[35:32]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[35:32])
);
pci_fifo_storage_Nx3 pci_fifo_storage_Nx3_38_36 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[38:36]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[38:36])
);


`ifdef NORMAL_PCI_CHECKS
`ifdef HOST_FIFO_DEPTH_3
  wire   [3:0] address_limit = 4'b0011;
`endif  // HOST_FIFO_DEPTH_3
`ifdef HOST_FIFO_DEPTH_5
  wire   [3:0] address_limit = 4'b0101;
`endif  // HOST_FIFO_DEPTH_5
`ifdef HOST_FIFO_DEPTH_7
  wire   [3:0] address_limit = 4'b0111;
`endif  // HOST_FIFO_DEPTH_7
`ifdef HOST_FIFO_DEPTH_15
  wire   [3:0] address_limit = 4'b1111;
`endif  // HOST_FIFO_DEPTH_15

  always @(posedge write_clk)
  begin
    if (($time > 0) & write_capture_data
          & ( ((write_address ^ write_address) === 1'bx)
              | (write_address[3:0] >= address_limit[3:0]) ) )
    begin
      $display ("*** %m %d - Write Address invalid %x, at %t",
                  address_limit[3:0], write_address[3:0], $time);
    end
    `NO_ELSE;
  end
  always @(posedge read_clk)
  begin
    if (($time > 0) & read_remove
          & ( ((read_address ^ read_address) === 1'bx)
              | (read_address[3:0] >= address_limit[3:0]) ) )
    begin
      $display ("*** %m %d - Read Address invalid %x, at %t",
                  address_limit[3:0], read_address[3:0], $time);
    end
    `NO_ELSE;
  end
  always @(posedge write_clk)
  begin
    if (($time > 0) & write_capture_data & ((write_data ^ write_data) === 1'bx) )
    begin
      $display ("*** %m - Write Data invalid 'h%x, at %t",
                  write_data, $time);
    end
    `NO_ELSE;
  end
`endif  // NORMAL_PCI_CHECKS
endmodule

// Verilog module used to implement the 40-bit-wide Host Response FIFO
// The Write Port is on the PCI side, so it gets the extra buffering needed
// to make the load activity depend on a single flop of state.
module pci_fifo_storage_response (
  reset_flags_async,
  fifo_mode,
  write_clk, write_sync_clk,
  write_submit,               // NOTE write_submit is VERY LATE
  write_room_available_meta,  // NOTE Needs extra settling time to avoid metastability
  write_data,
  write_error,
  read_clk, read_sync_clk,
  read_remove,
  read_data_available_meta,  // NOTE Needs extra settling time to avoid metastability
  read_data,
  read_error
);
  input   reset_flags_async;
  input  [1:0] fifo_mode;
  input   write_clk, write_sync_clk;
  input   write_submit;               // NOTE write_submit is VERY LATE
  output  write_room_available_meta;  // NOTE Needs extra settling time to avoid metastability
  input  [39:0] write_data;
  output  write_error;
  input   read_clk, read_sync_clk, read_remove;
  output  read_data_available_meta;  // NOTE Needs extra settling time to avoid metastability
  output [39:0] read_data;
  output  read_error;

  wire    double_sync_read_full_flag_const = 1'b0;
  wire    write_data_before_flag_const = (fifo_mode[1:0] == 2'b01);
  wire    read_flag_before_data_const = (fifo_mode[1:0] == 2'b10);

  wire   [3:0] write_address;
  wire   [3:0] read_address;
  wire    write_capture_data, read_enable;

  wire    write_room_available_meta_raw;
  reg     write_buffer_full_reg;
  wire    write_submit_int;
  wire   [39:0] write_data_int;
  reg    [39:0] write_data_reg;

// Note Make single FLOP which is used by FIFO Instantiator to know
// whether the FIFO Write Port has room or not.
// The Writer needs to only set this single Flop to indicate that
// the FIFO is full.  This module will try to mark the FIFO Empty
// whenever it can.  It can perform the actual FIFO load without
// concern for whether more data is available from the instantiating module

// FIFO Data Available Flag, which hopefully can operate with an
// Unload signal which has a MAX of 3 nSec setup time to the read clock.
  always @(posedge write_clk or posedge reset_flags_async)
  begin
    if (reset_flags_async == 1'b1)
    begin
      write_buffer_full_reg <= 1'b0;
    end
    else
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

pci_blue_fifo_flags pci_fifo_flags_response (
  .reset_flags_async          (reset_flags_async),
  .double_sync_read_full_flag_const   (double_sync_read_full_flag_const),
  .write_data_before_flag_const       (write_data_before_flag_const),
  .write_clk                  (write_clk),
  .write_sync_clk             (write_sync_clk),
  .write_submit               (write_submit_int),
  .write_capture_data         (write_capture_data),
  .write_room_available_meta  (write_room_available_meta_raw),
  .write_address              (write_address[3:0]),
  .write_error                (write_error),
  .read_flag_before_data_const        (read_flag_before_data_const),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_sync_clk),
  .read_remove                (read_remove),
  .read_enable                (read_enable),
  .read_data_available_meta   (read_data_available_meta),
  .read_two_words_available_meta (read_two_words_available_meta),
  .read_address               (read_address[3:0]),
  .read_error                 (read_error)
);

// Note manually instantiate custom sized SRAMs here, if available.
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_7_0 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data_int[7:0]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[7:0])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_15_8 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data_int[15:8]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[15:8])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_23_16 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data_int[23:16]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[23:16])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_31_24 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data_int[31:24]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[31:24])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_39_32 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data_int[39:32]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[39:32])
);
`ifdef NORMAL_PCI_CHECKS
`ifdef HOST_FIFO_DEPTH_3
  wire   [3:0] address_limit = 4'b0011;
`endif  // HOST_FIFO_DEPTH_3
`ifdef HOST_FIFO_DEPTH_5
  wire   [3:0] address_limit = 4'b0101;
`endif  // HOST_FIFO_DEPTH_5
`ifdef HOST_FIFO_DEPTH_7
  wire   [3:0] address_limit = 4'b0111;
`endif  // HOST_FIFO_DEPTH_7
`ifdef HOST_FIFO_DEPTH_15
  wire   [3:0] address_limit = 4'b1111;
`endif  // HOST_FIFO_DEPTH_15

  always @(posedge write_clk)
  begin
    if (($time > 0) & write_capture_data
          & ( ((write_address ^ write_address) === 1'bx)
              | (write_address[3:0] >= address_limit[3:0]) ) )
    begin
      $display ("*** %m %d - Write Address invalid %x, at %t",
                  address_limit[3:0], write_address[3:0], $time);
    end
    `NO_ELSE;
  end
  always @(posedge read_clk)
  begin
    if (($time > 0) & read_remove
          & ( ((read_address ^ read_address) === 1'bx)
              | (read_address[3:0] >= address_limit[3:0]) ) )
    begin
      $display ("*** %m %d - Read Address invalid %x, at %t",
                  address_limit[3:0], read_address[3:0], $time);
    end
    `NO_ELSE;
  end
  always @(posedge write_clk)
  begin
    if (($time > 0) & write_capture_data & ((write_data ^ write_data) === 1'bx) )
    begin
      $display ("*** %m - Write Data invalid 'h%x, at %t",
                  write_data, $time);
    end
    `NO_ELSE;
  end
`endif  // NORMAL_PCI_CHECKS
endmodule

// Verilog module used to implement the 35-bit-wide Delayed_Read Data FIFO
// The Read Port is on the PCI side, so it gets the extra buffering needed
// to make the unload activity depend on a single flop of state.
module pci_fifo_storage_delayed_read (
  reset_flags_async,
  fifo_mode,
  write_clk, write_sync_clk,
  write_submit,
  write_room_available_meta,  // NOTE Needs extra settling time to avoid metastability
  write_data,
  write_error,
  read_clk, read_sync_clk,
  read_remove,               // NOTE read_remove is VERY LATE
  read_data_available_meta,  // NOTE Needs extra settling time to avoid metastability
  read_data,
  read_error
);
  input   reset_flags_async;
  input  [1:0] fifo_mode;
  input   write_clk, write_sync_clk, write_submit;
  output  write_room_available_meta;  // NOTE Needs extra settling time to avoid metastability
  input  [34:0] write_data;
  output  write_error;
  input   read_clk, read_sync_clk;
  input   read_remove;               // NOTE read_remove is VERY LATE
  output  read_data_available_meta;  // NOTE Needs extra settling time to avoid metastability
  output [34:0] read_data;
  output  read_error;

  wire    double_sync_read_full_flag_const = 1'b0;
  wire    write_data_before_flag_const = (fifo_mode[1:0] == 2'b01);
  wire    read_flag_before_data_const = (fifo_mode[1:0] == 2'b10);

  wire   [3:0] write_address;
  wire   [3:0] read_address;
  wire    write_capture_data, read_enable;

pci_blue_fifo_flags pci_fifo_flags_delayed_read (
  .reset_flags_async          (reset_flags_async),
  .double_sync_read_full_flag_const   (double_sync_read_full_flag_const),
  .write_data_before_flag_const       (write_data_before_flag_const),
  .write_clk                  (write_clk),
  .write_sync_clk             (write_sync_clk),
  .write_submit               (write_submit),
  .write_capture_data         (write_capture_data),
  .write_room_available_meta  (write_room_available_meta),
  .write_address              (write_address[3:0]),
  .write_error                (write_error),
  .read_flag_before_data_const        (read_flag_before_data_const),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_sync_clk),
  .read_remove                (read_remove),
  .read_enable                (read_enable),
  .read_data_available_meta   (read_data_available_meta),
  .read_two_words_available_meta (read_two_words_available_meta),
  .read_address               (read_address[3:0]),
  .read_error                 (read_error)
);

// Note manually instantiate custom sized SRAMs here, if available.
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_7_0 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[7:0]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[7:0])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_15_8 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[15:8]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[15:8])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_23_16 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[23:16]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[23:16])
);
pci_fifo_storage_Nx8 pci_fifo_storage_Nx8_31_24 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[31:24]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[31:24])
);
pci_fifo_storage_Nx3 pci_fifo_storage_Nx3_34_32 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[34:32]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[34:32])
);
`ifdef NORMAL_PCI_CHECKS
`ifdef HOST_FIFO_DEPTH_3
  wire   [3:0] address_limit = 4'b0011;
`endif  // HOST_FIFO_DEPTH_3
`ifdef HOST_FIFO_DEPTH_5
  wire   [3:0] address_limit = 4'b0101;
`endif  // HOST_FIFO_DEPTH_5
`ifdef HOST_FIFO_DEPTH_7
  wire   [3:0] address_limit = 4'b0111;
`endif  // HOST_FIFO_DEPTH_7
`ifdef HOST_FIFO_DEPTH_15
  wire   [3:0] address_limit = 4'b1111;
`endif  // HOST_FIFO_DEPTH_15

  always @(posedge write_clk)
  begin
    if (($time > 0) & write_capture_data
          & ( ((write_address ^ write_address) === 1'bx)
              | (write_address[3:0] >= address_limit[3:0]) ) )
    begin
      $display ("*** %m %d - Write Address invalid %x, at %t",
                  address_limit[3:0], write_address[3:0], $time);
    end
    `NO_ELSE;
  end
  always @(posedge read_clk)
  begin
    if (($time > 0) & read_remove
          & ( ((read_address ^ read_address) === 1'bx)
              | (read_address[3:0] >= address_limit[3:0]) ) )
    begin
      $display ("*** %m %d - Read Address invalid %x, at %t",
                  address_limit[3:0], read_address[3:0], $time);
    end
    `NO_ELSE;
  end
  always @(posedge write_clk)
  begin
    if (($time > 0) & write_capture_data & ((write_data ^ write_data) === 1'bx) )
    begin
      $display ("*** %m - Write Data invalid 'h%x, at %t",
                  write_data, $time);
    end
    `NO_ELSE;
  end
`endif  // NORMAL_PCI_CHECKS
endmodule

module pci_fifo_storage_Nx8 (
  write_clk, write_capture_data,
  write_address, write_data,
  read_clk, read_enable,
  read_address, read_data
);
  input   write_clk, write_capture_data;
  input  [3:0] write_address;
  input  [7:0] write_data;
  input   read_clk, read_enable;
  input  [3:0] read_address;
  output [7:0] read_data;

pci_fifo_storage_Nx4 pci_fifo_storage_Nx4_3_0 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[3:0]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[3:0])
);
pci_fifo_storage_Nx4 pci_fifo_storage_Nx4_7_4 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[7:4]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[7:4])
);
endmodule

module pci_fifo_storage_Nx4 (
  write_clk, write_capture_data,
  write_address, write_data,
  read_clk, read_enable,
  read_address, read_data
);
  input   write_clk, write_capture_data;
  input  [3:0] write_address;
  input  [3:0] write_data;
  input   read_clk, read_enable;
  input  [3:0] read_address;
  output [3:0] read_data;

pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_0 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[0]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[0])
);
pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_1 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[1]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[1])
);
pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_2 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[2]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[2])
);
pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_3 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[3]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[3])
);
endmodule

module pci_fifo_storage_Nx3 (
  write_clk, write_capture_data,
  write_address, write_data,
  read_clk, read_enable,
  read_address, read_data
);
  input   write_clk, write_capture_data;
  input  [3:0] write_address;
  input  [2:0] write_data;
  input   read_clk, read_enable;
  input  [3:0] read_address;
  output [2:0] read_data;

pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_0 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[0]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[0])
);
pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_1 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[1]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[1])
);
pci_fifo_storage_Nx1 pci_fifo_storage_Nx1_2 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data[2]),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data[2])
);
endmodule

module pci_fifo_storage_Nx1 (
  write_clk, write_capture_data,
  write_address, write_data,
  read_clk, read_enable,
  read_address, read_data
);
  input   write_clk, write_capture_data;
  input  [3:0] write_address;
  input   write_data;
  input   read_clk, read_enable;
  input  [3:0] read_address;
  output  read_data;

// The FIFO can be made from descrete flops, or it can be made from memory elements.
`ifdef HOST_FIFOS_ARE_MADE_FROM_FLOPS
// Declare the Flip-Flops used by all sized FIFOs.
  reg     storage_0, storage_1, storage_2;

// When Flip-Flops are used for storage elements, writes are done by enabling them.
// These are the storage used by all sized FIFOs.
  always @(posedge write_clk)
  begin
    storage_0 <= (write_capture_data & (write_address[2:0] == 3'b000))
                                     ? write_data : storage_0;
    storage_1 <= (write_capture_data & (write_address[2:0] == 3'b001))
                                     ? write_data : storage_1;
    storage_2 <= (write_capture_data & (write_address[2:0] == 3'b010))
                                     ? write_data : storage_2;
  end

// model the synchronous output of the SRAM-based FIFO
  reg     read_enable_latched;
  always @(posedge read_clk)
  begin
    read_enable_latched <= read_enable;
  end

// When Flip-Flops are used for storage, reads are done via MUXes.
// This Mux is used by all sized FIFOs.
  wire    mux_10 = read_address[0] ? storage_1 : storage_0;

`ifdef HOST_FIFO_DEPTH_3
// When Flip_Flops are used for storage, reads are done via MUXes
  wire    read_selected = read_address[1] ? storage_2 : mux_10;
  assign  read_data = read_enable_latched ? read_selected : 1'bX;
`endif  // HOST_FIFO_DEPTH_3

`ifdef HOST_FIFO_DEPTH_5
// Declare the Flip-Flops used only in 5-deep FIFOs.
  reg     storage_3, storage_4;

// When Flip-Flops are used for storage elements, writes are done by enabling them.
  always @(posedge write_clk)
  begin
    storage_3 <= (write_capture_data & (write_address[2:0] == 3'b011))
                                     ? write_data : storage_3;
    storage_4 <= (write_capture_data & (write_address[2:0] == 3'b100))
                                     ? write_data : storage_4;
  end

// When Flip-Flops are used for storage, reads are done via MUXes.
  wire    mux_32 =    read_address[0] ? storage_3 : storage_2;
  wire    mux_3210 =  read_address[1] ? mux_32    : mux_10;
  wire    read_selected = read_address[2] ? storage_4 : mux_3210;
  assign  read_data = read_enable_latched ? read_selected : 1'bX;
`endif  // HOST_FIFO_DEPTH_5

`ifdef HOST_FIFO_DEPTH_7
// Declare the Flip-Flops used only in 7-deep FIFOs.
  reg     storage_3, storage_4, storage_5, storage_6;

// When Flip-Flops are used for storage elements, writes are done by enabling them.
  always @(posedge write_clk)
  begin
    storage_3 <= (write_capture_data & (write_address[2:0] == 3'b011))
                                     ? write_data : storage_3;
    storage_4 <= (write_capture_data & (write_address[2:0] == 3'b100))
                                     ? write_data : storage_4;
    storage_5 <= (write_capture_data & (write_address[2:0] == 3'b101))
                                     ? write_data : storage_5;
    storage_6 <= (write_capture_data & (write_address[2:0] == 3'b110))
                                     ? write_data : storage_6;
  end

// When Flip-Flops are used for storage, reads are done via MUXes.
  wire    mux_32 =    read_address[0] ? storage_3 : storage_2;
  wire    mux_54 =    read_address[0] ? storage_5 : storage_4;
  wire    mux_3210 =  read_address[1] ? mux_32    : mux_10;
  wire    mux_654 =   read_address[1] ? storage_6 : mux_54;
  wire    read_selected = read_address[2] ? mux_654   : mux_3210;
  assign  read_data = read_enable_latched ? read_selected : 1'bX;
`endif  // HOST_FIFO_DEPTH_7

`ifdef HOST_FIFO_DEPTH_15
XXXX  Intentional Syntax Error.  Need to undefine HOST_FIFOS_ARE_MADE_FROM_FLOPS
XXXX  whenever the FIFO Size is selected to be depth 15.
`endif  // HOST_FIFO_DEPTH_15

`else  // HOST_FIFOS_ARE_MADE_FROM_FLOPS
// Use the vendor's dual-port SRAM primitive.  This SRAM must store 16 elements.
pci_2port_sram_16x1 pci_2port_sram_16x1 (
  .write_clk                  (write_clk),
  .write_capture_data         (write_capture_data),
  .write_address              (write_address[3:0]),
  .write_data                 (write_data),
  .read_clk                   (read_clk),
  .read_enable                (read_enable),
  .read_address               (read_address[3:0]),
  .read_data                  (read_data)
);
`endif  // HOST_FIFOS_ARE_MADE_FROM_FLOPS
endmodule

