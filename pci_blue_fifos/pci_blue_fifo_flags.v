//===========================================================================
// $Id: pci_blue_fifo_flags.v,v 1.7 2001-07-01 06:39:03 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The Fifo Flag module.  This module keeps track of the full/empty
//           status of the Request, Response, and Delayed Read Data FIFOs.
//           This module has two parts, each operating on its own independent
//           clock.  There is no relationship between clocks, and in fact one
//           or both of the clocks can stop.
//           The Write side and the Read side of the FIFOs communicate by
//           sending and receiving a grey-coded indication of FIFO status.
//           The Write side of the Fifo operates in one of two main modes:
//           1) Fifo writes Data and updates Flags at the same time.
//           2) Fifo writes Data, then updates Flags the next clock.
//           The Read side of the Fifo operates in one of two main modes:
//           1) Fifo is constantly being read.  Data and Data Available
//              become true at the same time.
//           2) Data Available in one clock causes Data to be read the next clock.
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
// NOTE:  This module implements the flags used to communicate from one
//          clock domain to another about whether an entry in a FIFO is full.
//
// NOTE:  This module exports two signals (the full and empty bits) which
//          are GUARANTEED to have metastable conditions on them.  These two
//          signals must be constraintd to have EXTRA SETUP TIME to the
//          dependent flops, to let them settle to stable values.  This
//          is VERY IMPORANT, because several flops all act on the same
//          changing value.  Without constraints, that will always cause
//          disaster.
//
// NOTE:  The two signals which have to be constrainted to have extra
//          settling time to the next clock edge are
//          read_side_not_empty and write_side_not_full.
//        If these signals are not correctly constrainted, this design will FAIL.
//
// NOTE:  The constraints will be described as setup and hold constraints between
//          signals in the clock domains read_clk and read_sync_clk, and between
//          signals in the clock domains write_clk and write_sync_clk.
//        These clocks will actually be the same clock in an upper scope.  Hopefully
//          it will still be possible to place constraints down here.
//
// NOTE:  Chip Testing will require that the two clock domains read_clk and write_clk
//          either run at the same speed, or at some muliple of one-another.
//        In either case, there will need to be constraints between write_clk and
//          read_sync_clk, and between read_clk and write_sync_clk.
//        It would seem that a false-path constraint would be called for, because in
//          real life there is no clock-to-clock constraint.  However, in a chip
//          tester these clock domains are locked together, and the signals must be
//          constrainted to make sure that cycle-accuracy is achieved.
//
// NOTE:  The flags will be reset to all empty asynchronously, since this
//          code does not know whether the reader or the writer is doing the
//          reset.
//
// NOTE:  Either or both of the clocks can stop.  The circuit must carefully
//          reset even if the clocks stop.
//
// NOTE:  This module is responsible for moving events between the Read and
//          Write clock domains.  This is achieved by synchronizing control
//          which cross between clocks.  In order for things to settle safely,
//          there must be a large time between when the control signals are
//          latched and when they are used.
//        The latched Control Signals will go through some combinational logic
//          before use.  The combinational delay subtracts directly from the
//          available settling time.
//        The PCI Side of the interface will probably be in pretty good shape.
//          The fastest PCI clock is 15 nSec, and it should be possible to latch
//          the signal, do combinational logic, and set up to the next flop in
//          much less than 15 nSec, giving plenty of time to settle.
//        The Host Interface side might be more difficult.  A Host Clock rate of
//          250 MHz would leave 4 nSec for clock-to-output, logic, data-to-clock,
//          plus the time to settle out of metastability.  This might be hard.
//        This module lets the user specify that one or both of the ports needs
//          to have the control signals double-latched before use.  Then it will
//          be easy to meat timing.
//        For instance, the Read Port might be running on the Host clock.  The
//          Read Port can be instructed to double synchronize.  It would then be
//          able to run at a high clock rate.
//
// NOTE:  Even with the double-synchronization, it will be possible to have the
//          circuit misbehave.  This is because Synthesis and Place-and-Route
//          software wants to use up all the time available to it.  These tools
//          substitute slow logic when they can.  Slow logic can eat up the
//          necessary settling time.
//        To keep synthesis from breaking the circuit, it is necessary to constrain
//          the OUTPUTS of the synchronizer flops to arive at the next flop input
//          with significant setup margin.
//        The constraints can either be point-to-point, or they can be between all
//          sources in one clock domain and destinations in the other.
//        These constraints are CRITICAL to the correct function of this circuit.
//        At least 2 nSec, and preferably 3 nSec or more, should be budgeted for
//          synchronized signal settling time.
//
// NOTE:  The amount of storage in each FIFO will need to be decided upon by
//          the system designer.
//        The Host_Request FIFO is 39 bits wide, the Host_Response FIFO is
//          40 bits wide, and the Delayed_Read_Data FIFO is 35 bits wide.
//        If each of the 3 FIFOs are implemented as 3-entry FIFOs, that will
//          take a total of around 350 Flops, which is a very modest number.
//          This might even be useful in an FPGA.
//        If each of the 3 FIFOs are 7-entry FIFOs, that will take around 800
//          flops.  Again, this is modest for a gate array or standard cell
//          implementation, but is probably difficult to achieve in an FPGA.
//          An FPGA might use dual-port elements as described below, but only
//          use 7 entries in each, to model a standard cell or gate array version.
//        If each of the 3 FIFOs are 15-entry FIFOs, that will take around 1800
//          flops.  This is starting to be a large number of flops even for a
//          gate array or standard cell implementation.  However, an FPGA or
//          vendor library might contain a small dual-port SRAM, which might
//          be an economical way to implement the FIFOs.  A Xilinx chip might
//          use 16x1 Dual Port SRAM elements, for instance, and use about 115
//          CLBs for all FIFOs together.  This would be about the same area
//          as the 3-element FIFOs implemented using simple flops.
//
// NOTE:  This design also allows the use of a 5-entry FIFO, as well as the
//          more likely 3, 7, and 15 entries.  This might be an attractive
//          compromise in FIFO size.
//
// NOTE:  This module does not worry about how the circuit will be tested
//          on the chip tester.  One good way to test this would be to make
//          the Reader and Writer clocks be identical during test mode.  Then
//          all communication between clock domains would act as normal one-
//          clock transfers in a synchronous circuit.
//
// NOTE:  This circuit might be implemented in many ways.  One way would be
//          to have a Read Pointer and a Write Pointer.  These would typically
//          be implemented as Grey Code counters.  Grey Code counters can safely
//          cross clock boundries, as long as the counter is synchronized by
//          a metastable-safe synchronizer on the receive side.
//          Another way to implement this would be to have read and write
//          pointers local to each side, and full/empty bits for each entry.
//          These full/empty bits must also be synchronized upon crossing
//          the clock boundries.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

// verilog module used to implement full flags in a FIFO

module pci_blue_fifo_flags (
  reset_flags_async,
  double_sync_read_full_flag_const,
  write_data_before_flag_const,
  write_clk, write_sync_clk, write_submit, write_capture_data,
  write_room_available_meta,  // NOTE Needs extra settling time to avoid metastability
  write_address,
  write_error,
  read_flag_before_data_const,
  read_clk, read_sync_clk, read_remove, read_enable,
  read_data_available_meta,  // NOTE Needs extra settling time to avoid metastability
  read_address,
  read_error
);
  input   reset_flags_async;
  input   double_sync_read_full_flag_const;
  input   write_data_before_flag_const;
  input   write_clk, write_sync_clk;
  input   write_submit;  // from side which is submitting data
  output  write_capture_data;  // to data storage elements (to power up?)
  output  write_room_available_meta;
  output [3:0] write_address;
  output  write_error;
  input   read_flag_before_data_const;
  input   read_clk, read_sync_clk;
  input   read_remove;  // from side which is removing data
  output  read_enable;  // to data storage elements (to power up?)
  output  read_data_available_meta;
  output [3:0] read_address;
  output  read_error;

function  [3:0] address_inc;
  input   [3:0] address_in;
  begin
`ifdef HOST_FIFO_DEPTH_3
// FIFO is 3 entries long.  Count 0, 1, 2, 0, 1, 2
    address_inc[3:2] = 2'b00;
    address_inc[1:0] = (address_in[1:0] < 2'b10)
                     ?  address_in[1:0] + 2'b01 : 2'b00;
`endif  // HOST_FIFO_DEPTH_3
`ifdef HOST_FIFO_DEPTH_5
// FIFO is 5 entries long.  Count 0, 1, 2, 3, 4, 0, 1, 2, 3, 4
    address_inc[3] = 1'b0;
    address_inc[2:0] = (address_in[2:0] < 3'b100)
                     ?  address_in[2:0] + 3'b001 : 3'b000;
`endif  // HOST_FIFO_DEPTH_5
`ifdef HOST_FIFO_DEPTH_7
// FIFO is 7 entries long.  Count 0, 1, 2, 3, 4, 5, 6, 0, 1, 2
    address_inc[3] = 1'b0;
    address_inc[2:0] = (address_in[2:0] < 3'b110)
                     ?  address_in[2:0] + 3'b001 : 3'b000;
`endif  // HOST_FIFO_DEPTH_7
`ifdef HOST_FIFO_DEPTH_15
// FIFO is 15 entries long.  Count from 0 up to 14, then wrap to 0.
    address_inc[3:0] = (address_in[3:0] < 4'b1110)
                     ?  address_in[3:0] + 4'b0001 : 4'b0000;
`endif  // HOST_FIFO_DEPTH_5
  end
endfunction

// This counter represents 0, 1, 2, .., up to N entries.
function  [3:0] grey_code_counter_inc;
  input   [3:0] counter_in;
  begin
`ifdef HOST_FIFO_DEPTH_3
// FIFO is 3 entries long
    grey_code_counter_inc[3:2] = 2'b00;
    case (counter_in[1:0])
    2'b00: grey_code_counter_inc[1:0] = 2'b01;
    2'b01: grey_code_counter_inc[1:0] = 2'b11;
    2'b11: grey_code_counter_inc[1:0] = 2'b10;
    2'b10: grey_code_counter_inc[1:0] = 2'b00;
    default:
      begin
        grey_code_counter_inc[1:0] = 2'b00;
// synopsys translate_off
        if ($time > 0)
        begin
          $display ("*** fifo pointer has invalid value %h, at %t",
                                                 counter_in[3:0], $time);
        end
        `NO_ELSE;
// synopsys translate_on
      end
    endcase
`endif  // HOST_FIFO_DEPTH_3
`ifdef HOST_FIFO_DEPTH_5
// FIFO is  5 entries long
    grey_code_counter_inc[3] = 1'b0;
    case (counter_in[2:0])
    3'b000: grey_code_counter_inc[2:0] = 3'b001;
    3'b001: grey_code_counter_inc[2:0] = 3'b011;
    3'b011: grey_code_counter_inc[2:0] = 3'b010;
    3'b010: grey_code_counter_inc[2:0] = 3'b110;
    3'b110: grey_code_counter_inc[2:0] = 3'b100;
    3'b100: grey_code_counter_inc[2:0] = 3'b000;
    default:
      begin
        grey_code_counter_inc[2:0] = 3'b000;
// synopsys translate_off
        if ($time > 0)
        begin
          $display ("*** fifo pointer has invalid value %h, at %t",
                                                 counter_in[3:0], $time);
        end
        `NO_ELSE;
// synopsys translate_on
      end
    endcase
`endif  // HOST_FIFO_DEPTH_5
`ifdef HOST_FIFO_DEPTH_7
// FIFO is  7 entries long
    grey_code_counter_inc[3] = 1'b0;
    case (counter_in[2:0])
    3'b000: grey_code_counter_inc[2:0] = 3'b001;
    3'b001: grey_code_counter_inc[2:0] = 3'b011;
    3'b011: grey_code_counter_inc[2:0] = 3'b010;
    3'b010: grey_code_counter_inc[2:0] = 3'b110;
    3'b110: grey_code_counter_inc[2:0] = 3'b111;
    3'b111: grey_code_counter_inc[2:0] = 3'b101;
    3'b101: grey_code_counter_inc[2:0] = 3'b100;
    3'b100: grey_code_counter_inc[2:0] = 3'b000;
    default:
      begin
        grey_code_counter_inc[2:0] = 3'b000;
// synopsys translate_off
        if ($time > 0)
        begin
          $display ("*** fifo pointer has invalid value %h, at %t",
                                                 counter_in[3:0], $time);
        end
        `NO_ELSE;
// synopsys translate_off
      end
    endcase
`endif  // HOST_FIFO_DEPTH_7
`ifdef HOST_FIFO_DEPTH_15
// FIFO is 15 entries long
    case (counter_in[3:0])
    4'b0000: grey_code_counter_inc[3:0] = 4'b0001;
    4'b0001: grey_code_counter_inc[3:0] = 4'b0011;
    4'b0011: grey_code_counter_inc[3:0] = 4'b0010;
    4'b0010: grey_code_counter_inc[3:0] = 4'b0110;
    4'b0110: grey_code_counter_inc[3:0] = 4'b0111;
    4'b0111: grey_code_counter_inc[3:0] = 4'b0101;
    4'b0101: grey_code_counter_inc[3:0] = 4'b0100;
    4'b0100: grey_code_counter_inc[3:0] = 4'b1100;
    4'b1100: grey_code_counter_inc[3:0] = 4'b1101;
    4'b1101: grey_code_counter_inc[3:0] = 4'b1111;
    4'b1111: grey_code_counter_inc[3:0] = 4'b1110;
    4'b1110: grey_code_counter_inc[3:0] = 4'b1010;
    4'b1010: grey_code_counter_inc[3:0] = 4'b1011;
    4'b1011: grey_code_counter_inc[3:0] = 4'b1001;
    4'b1001: grey_code_counter_inc[3:0] = 4'b1000;
    4'b1000: grey_code_counter_inc[3:0] = 4'b0000;
    default:
      begin
        grey_code_counter_inc[3:0] = 4'h0;
// synopsys translate_off
        if ($time > 0)
        begin
          $display ("*** fifo pointer has invalid value %h, at %t",
                                                 counter_in[3:0], $time);
        end
        `NO_ELSE;
// synopsys translate_off
      end
    endcase
`endif  // HOST_FIFO_DEPTH_15
  end
endfunction

// These FIFOs are guarded by two grey-code counters.
// These counters have to work with stopable clocks.  Each counter
//   might therefore change by more than 1 step when observed from the
//   other clock domain.  Hopefully, the counters will never overrun.
// When write_counter == read_counter, the FIFO is empty.
// When a word is added on the write side, the write_counter is incremented.
//   The pointers no longer match, so the fifo is no longer empty.
// When a word is removed on the read side, the read_counter
//   is incremented.  The pointers match again, so the FIFO is empty.
// If a bunch of writes are done in sequence, the FIFO might fill up.
// The FIFO is full when the write_counter + 1 == read_counter, where
//   the + operation is done as a grey-code increment.
// Since the grey-code counter counts from 0 to N, it can signify that
//   there are 0 to N-1 entries.  A 2-bit grey-code counter can
//   signify that there are 0, 1, 2, or 3 full entries.  Therefore, there
//   only need to be 3 storage elements!
// This FIFO maintains a read_address and write_address which point to
//   the actual entry next to be referenced.  Even though the grey-code
//   counter is counting modulo N, the address counter counts module (N - 1).

// Allow a word to be written to the WRITE side of the FIFO if it is not full.
  wire   [3:0] sync_read_greycode_counter;
  reg    [3:0] double_sync_read_greycode_counter;
  reg    [3:0] write_greycode_counter;
  reg    [3:0] delayed_write_greycode_counter;
  reg    [3:0] write_address;
  reg     write_error;

// Either Single-Sync or Double-Sync the read address.  The Double-Sync should
// be selected if the write-side clock is so fast that it is impossible to use
// the Single-Sync version of the read counter with enough leftover time to let
// the metastability settle out.
  wire   [3:0] selected_sync_read_greycode_counter = double_sync_read_full_flag_const
                                       ? double_sync_read_greycode_counter[3:0]
                                       : sync_read_greycode_counter[3:0];
  wire   [3:0] next_write_greycode_counter =
                          grey_code_counter_inc (write_greycode_counter[3:0]);
  wire    write_side_not_full = (next_write_greycode_counter[3:0]
                                  != selected_sync_read_greycode_counter[3:0]);

// Tell outside world room available.  NOTE possible metastability!
  assign  write_room_available_meta = write_side_not_full;

// Only capture data when there is room available.  Otherwise error.
  assign  write_capture_data = (write_submit & write_side_not_full);

  always @(posedge write_clk or posedge reset_flags_async)
  begin
    if (reset_flags_async == 1'b1)
    begin
      write_greycode_counter[3:0] <= 4'h0;
      write_address[3:0] <= 4'h0;
      delayed_write_greycode_counter[3:0] <= 4'h0;
      write_error <= 1'b0;
      double_sync_read_greycode_counter[3:0] <= 4'h0;
    end
    else
    begin
      if (write_submit & write_side_not_full)
      begin
        write_greycode_counter[3:0] <= next_write_greycode_counter[3:0];
        write_address[3:0] <= address_inc (write_address[3:0]);
      end
      else
      begin
        write_greycode_counter[3:0] <= write_greycode_counter[3:0];
        write_address[3:0] <= write_address[3:0];
      end
      delayed_write_greycode_counter[3:0] <= write_greycode_counter[3:0];
      write_error <= (write_submit & ~write_side_not_full);
      double_sync_read_greycode_counter[3:0] <= sync_read_greycode_counter[3:0];
    end
  end

// Either write the Data and Full indication at the same time, or delay the
// Full indication by 1 clock.  In case that data is written before the valid
// bit, send a delayed Write Address to the Read side so that it is guaranteed
// to be valid after the data is.  Delaying the Full INdication is needed if the
// Read side of the FIFO will act on the Data the same clock it detects Full.
  wire   [3:0] read_side_write_counter = write_data_before_flag_const
                                       ? delayed_write_greycode_counter[3:0]
                                       : write_greycode_counter[3:0];

// Allow a word to be read from the Read side of the FIFO if it is not empty.
  wire   [3:0] sync_write_greycode_counter;
  reg    [3:0] double_sync_write_greycode_counter;
  reg    [3:0] read_greycode_counter;
  reg    [3:0] read_address;
  reg     read_error;

// Either read the Full Flag at the same time as the Data, or read the Full Flag
// one clock before the data is used.  Use the case of Data after Flag when
// the read-side clock is faster than the write side clock.  In this case,
// the write side will have been set to write Data and Flag at the same time.
// The read side has to wait after the flag is seen to make sure the data is valid.
  wire   [3:0] selected_sync_write_greycode_counter = read_flag_before_data_const
                                       ? double_sync_write_greycode_counter[3:0]
                                       : sync_write_greycode_counter[3:0];
  wire    read_side_not_empty = (read_greycode_counter[3:0]
                                      != selected_sync_write_greycode_counter[3:0]);

// Tell outside world data available.  NOTE possible metastability!
  assign  read_data_available_meta = read_side_not_empty;

// Either read constantly if Read Data needs to be available at the same time as
//   the Flag is seen as valid, or only read whenever Data is known to be available.
  assign  read_enable = ~read_flag_before_data_const
                      | (read_flag_before_data_const & read_side_not_empty);

  always @(posedge read_clk or posedge reset_flags_async)
  begin
    if (reset_flags_async == 1'b1)
    begin
      read_greycode_counter[3:0] <= 4'h0;
      read_address[3:0] <= 4'h0;
      read_error <= 1'b0;
      double_sync_write_greycode_counter[3:0] <= 4'h0;
    end
    else
    begin
      if (read_remove & read_side_not_empty)
      begin
        read_greycode_counter[3:0] <=
                   grey_code_counter_inc (read_greycode_counter[3:0]);
        read_address[3:0] <= address_inc (read_address[3:0]);
      end
      else
      begin
        read_greycode_counter[3:0] <= read_greycode_counter[3:0];
        read_address[3:0] <= read_address[3:0];
      end
      read_error <= read_remove & ~read_side_not_empty;
      double_sync_write_greycode_counter[3:0] <= sync_write_greycode_counter[3:0];
    end
  end

// This FIFO Flag module depends on the fact that the storage elements holding
//   the FIFO data, be they SRAM or registers, can make Write Data available
//   on the Read port at most 1 clock of the FASTER of the Read and Write clock
//   after the data is written.
// Since this guarantee is made, it will always be safe to read the data after
//   the FIFO counter is seen in the Read clock domain the very first time.

// Capture a copy of the Write pointer to use in the Read clock domain
pci_synchronizer_flop sync_read_counter_0 (
  .data_in                    (read_greycode_counter[0]),
  .clk_out                    (write_sync_clk),
  .sync_data_out              (sync_read_greycode_counter[0]),
  .async_reset                (reset_flags_async)
);
pci_synchronizer_flop sync_read_counter_1 (
  .data_in                    (read_greycode_counter[1]),
  .clk_out                    (write_sync_clk),
  .sync_data_out              (sync_read_greycode_counter[1]),
  .async_reset                (reset_flags_async)
);
pci_synchronizer_flop sync_read_counter_2 (
  .data_in                    (read_greycode_counter[2]),
  .clk_out                    (write_sync_clk),
  .sync_data_out              (sync_read_greycode_counter[2]),
  .async_reset                (reset_flags_async)
);
pci_synchronizer_flop sync_read_counter_3 (
  .data_in                    (read_greycode_counter[3]),
  .clk_out                    (write_sync_clk),
  .sync_data_out              (sync_read_greycode_counter[3]),
  .async_reset                (reset_flags_async)
);

// Capture a copy of the Read pointer to use in the Write clock domain
pci_synchronizer_flop sync_write_counter_0 (
  .data_in                    (read_side_write_counter[0]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (sync_write_greycode_counter[0]),
  .async_reset                (reset_flags_async)
);
pci_synchronizer_flop sync_write_counter_1 (
  .data_in                    (read_side_write_counter[1]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (sync_write_greycode_counter[1]),
  .async_reset                (reset_flags_async)
);
pci_synchronizer_flop sync_write_counter_2 (
  .data_in                    (read_side_write_counter[2]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (sync_write_greycode_counter[2]),
  .async_reset                (reset_flags_async)
);
pci_synchronizer_flop sync_write_counter_3 (
  .data_in                    (read_side_write_counter[3]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (sync_write_greycode_counter[3]),
  .async_reset                (reset_flags_async)
);

  always @(negedge reset_flags_async)
  begin
    if (($time > 0) & ~write_data_before_flag_const & ~read_flag_before_data_const)
    begin
      $display ("*** pci_fifo_flags - ASYNC FIFO must either write Data before Flag, or read Data after Flag, at %t",
                  $time);
    end
    `NO_ELSE;
  end
`ifdef NORMAL_PCI_CHECKS
  always @(posedge write_clk)
  begin
    if (($time > 0) & ~reset_flags_async & ((write_submit ^ write_submit) === 1'bX))
    begin
      $display ("*** pci_fifo_flags - Write_Submit invalid, at %t",
                  write_submit, $time);
    end
    `NO_ELSE;
  end
  always @(posedge read_clk)
  begin
    if (($time > 0) & ~reset_flags_async & ((read_remove ^ read_remove) === 1'bX))
    begin
      $display ("*** pci_fifo_flags - Read_Remove invalid, at %t",
                  read_remove, $time);
    end
    `NO_ELSE;
  end
`endif  // NORMAL_PCI_CHECKS
endmodule

