//===========================================================================
// $Id: test_pci_fifos.v,v 1.6 2001-06-20 11:25:11 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  A top-level module to exercise the FIFOs and FIFO Flags.
//           Unfortunately, both sides are operated on the same clock.
//           Not a very good diagnostic.
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
// NOTE:  This module is used to test the FIFOs.
//        It will not be instantiated in the real PCI interface.
//
// NOTE:  This module must test the FIFOs in several main modes:
//        Mode 1: Write Data and Full Flag at the same time.
//        Mode 2: Write Data first, then write Full Flag.
//        Mode 3: Read Full Flag first, then read Data.
//        Mode 4: Read Full Flag and Data at the same time.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_test_fifos ();
  reg     write_clk, read_clk;
  reg     reset_flags_async;
  reg     double_sync_write_empty_flag_const, double_sync_read_full_flag_const;
  reg     write_data_before_flag_const, read_flag_before_data_const;
  reg    [39:0] write_data;
  reg     write_submit;
  wire    write_room_available_meta_35;
  wire    write_room_available_meta_39;
  wire    write_room_available_meta_40;
  reg     read_remove;
  wire    read_data_available_meta_35;
  wire    read_data_available_meta_39;
  wire    read_data_available_meta_40;
  wire    write_error_35, write_error_39, write_error_40;
  wire    read_error_35, read_error_39, read_error_40;
  wire   [34:0] read_data_35;
  wire   [38:0] read_data_39;
  wire   [39:0] read_data_40;

  reg     test_error_event;
  initial test_error_event <= 1'b0;
  reg     error_detected;
  initial error_detected <= 1'b0;
  always @(error_detected)
  begin
    test_error_event <= 1'b1;
    #2;
    test_error_event <= 1'b0;
  end


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
  initial $display ("Fifo Depth is 'h%h", address_limit);

function [39:0] smear_digits;
  input  [3:0] digit;
  assign  smear_digits = {digit[3:0], digit[3:0],
                          digit[3:0], digit[3:0], digit[3:0], digit[3:0],
                          digit[3:0], digit[3:0], digit[3:0], digit[3:0]};
endfunction

task check_error_status;
  input   write_error, read_error;
  begin
    if (write_error_35 !== write_error)
    begin
      $display ("*** write_error_35 %h, not as expected %h, at %t",
                 write_error_35, write_error, $time);
       error_detected = ~error_detected;
    end
    if (write_error_39 !== write_error)
    begin
      $display ("*** write_error_39 %h, not as expected %h, at %t",
                 write_error_39, write_error, $time);
       error_detected = ~error_detected;
    end
    if (write_error_40 !== write_error)
    begin
      $display ("*** write_error_40 %h, not as expected %h, at %t",
                 write_error_40, write_error, $time);
       error_detected = ~error_detected;
    end
    if (read_error_35 !== read_error)
    begin
      $display ("*** read_error_35 %h, not as expected %h, at %t",
                 read_error_35, read_error, $time);
       error_detected = ~error_detected;
    end
    if (read_error_39 !== read_error)
    begin
      $display ("*** read_error_39 %h, not as expected %h, at %t",
                 read_error_39, read_error, $time);
       error_detected = ~error_detected;
    end
    if (read_error_40 !== read_error)
    begin
      $display ("*** read_error_40 %h, not as expected %h, at %t",
                 read_error_40, read_error, $time);
       error_detected = ~error_detected;
    end
  end
endtask

task check_no_error;
  begin
    check_error_status (1'b0, 1'b0);
  end
endtask

task check_write_error;
  begin
    check_error_status (1'b1, 1'b0);
  end
endtask

task check_read_error;
  begin
    check_error_status (1'b0, 1'b1);
  end
endtask

task check_fifo_status;
  input   write_not_full_flag, read_data_available_flag;
  begin
    if (write_room_available_meta_35 !== write_not_full_flag)
    begin
      $display ("*** write_room_available_meta_35 %h, not as expected %h, at %t",
                 write_room_available_meta_35, write_not_full_flag, $time);
       error_detected = ~error_detected;
    end
    if (write_room_available_meta_39 !== write_not_full_flag)
    begin
      $display ("*** write_room_available_meta_39 %h, not as expected %h, at %t",
                 write_room_available_meta_39, write_not_full_flag, $time);
       error_detected = ~error_detected;
    end
    if (write_room_available_meta_40 !== write_not_full_flag)
    begin
      $display ("*** write_room_available_meta_40 %h, not as expected %h, at %t",
                 write_room_available_meta_40, write_not_full_flag, $time);
       error_detected = ~error_detected;
    end
    if (read_data_available_meta_35 !== read_data_available_flag)
    begin
      $display ("*** read_data_available_meta_35 %h, not as expected %h, at %t",
                 read_data_available_meta_35, read_data_available_flag, $time);
       error_detected = ~error_detected;
    end
    if (read_data_available_meta_39 !== read_data_available_flag)
    begin
      $display ("*** read_data_available_meta_39 %h, not as expected %h, at %t",
                 read_data_available_meta_39, read_data_available_flag, $time);
       error_detected = ~error_detected;
    end
    if (read_data_available_meta_40 !== read_data_available_flag)
    begin
      $display ("*** read_data_available_meta_40 %h, not as expected %h, at %t",
                 read_data_available_meta_40, read_data_available_flag, $time);
       error_detected = ~error_detected;
    end
  end
endtask

task check_empty;
  begin
    check_fifo_status (1'b1, 1'b0);
  end
endtask

task check_not_empty_not_full;
  begin
    check_fifo_status (1'b1, 1'b1);
  end
endtask

task check_full;
  begin
    check_fifo_status (1'b0, 1'b1);
  end
endtask

task check_write_full_read_empty;
  begin
    check_fifo_status (1'b0, 1'b0);
  end
endtask

task check_value;
  input  [39:0] expected_data;
  begin
    if (read_data_35[34:0] !== expected_data[34:0])
    begin
      $display ("*** read_data_35 'h%h, not as expected 'h%h, at %t",
                 read_data_35[34:0], expected_data[34:0], $time);
       error_detected = ~error_detected;
    end
    if (read_data_39[38:0] !== expected_data[38:0])
    begin
      $display ("*** read_data_39 'h%h, not as expected 'h%h, at %t",
                 read_data_39[38:0], expected_data[38:0], $time);
       error_detected = ~error_detected;
    end
    if (read_data_40[39:0] !== expected_data[39:0])
    begin
      $display ("*** read_data_40 'h%h, not as expected 'h%h, at %t",
                 read_data_40[39:0], expected_data[39:0], $time);
       error_detected = ~error_detected;
    end
  end
endtask

task do_both_clocks;
  begin
    #2.5;
    read_clk = 1'b1;
    write_clk = 1'b1;
    #5.0;
    read_clk = 1'b0;
    write_clk = 1'b0;
    #2.5;
  end
endtask

task write_one_fifo_entry;
  input  [39:0] in_data;
  begin
    write_data[39:0] = in_data[39:0];
    write_submit = 1'b1;
    read_remove = 1'b0;
    do_both_clocks;  // data and maybe flags get written
    write_data[39:0] = 40'hXX_XXXX_XXXX;
    if (write_data_before_flag_const)
    begin
      check_no_error;
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // if flag wasn't sent the previous time, send it now.
    end
  end
endtask

task when_empty_write_one_look_for_one_read_data;
  input  [39:0] in_data;
  begin
    $display ("Checking that empty FIFO's accept 1 word, at time %t", $time);
    write_one_fifo_entry (in_data[39:0]);
    check_no_error;

// The Test Setup has the Read and Write clocks running at the same frequency.
// This expects Data + flag, or Data then Flag.  The clock after the Flag is set,
//   it is grabbed by the Read synchronizer.  The read side either acts on it
//   immediately if it knows that the Write side is delaying things, or it waits
//   one extra clock if it thinks the Read Data may not be valid yet.

// Wait an extra clock if the FIFO thinks it must delay till the data settles.
    if (read_flag_before_data_const)
    begin
      check_empty;
      check_no_error;
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and maybe data visible to the receiver
    end

// Wait the required clock period to let the Flag go through the synchronizer.
    check_empty;
    check_no_error;
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;  // make flags and maybe data visible to the receiver

    check_not_empty_not_full;
    check_no_error;

    check_value (in_data[39:0]);

    write_submit = 1'b0;
    read_remove = 1'b1;
    do_both_clocks; 

    check_empty;
    check_no_error;

    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;
    check_empty;
    check_no_error;

    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;
    check_empty;
    check_no_error;

  end
endtask

task fill_fifo;
  input  [39:0] in_data;
  reg [3:0] counter;
  begin
    $display ("Fill then OverFill the FIFOs, at time %t", $time);
    for (counter[3:0] = 4'h0; counter[3:0] < address_limit[3:0];
                              counter[3:0] = counter[3:0] + 4'h1)
    begin
      write_one_fifo_entry (in_data[39:0]);
      check_no_error;
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
    end
    check_full;
  end
endtask

task overfill_fifo;
  begin
    check_full;
    write_data[39:0] = 40'hXX_XXXX_XXXX;
    write_submit = 1'b1;
    read_remove = 1'b0;
    do_both_clocks;  // overrun the FIFO this time for sure
    check_write_error;
    check_full;
  end
endtask

task empty_fifo;
  input  [39:0] in_data;
  reg    [3:0] counter;
  begin
    $display ("Empty then OverEmpty the FIFOs, at time %t", $time);
    write_data[39:0] = 40'hXX_XXXX_XXXX;
    check_full;
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;  // make flags and data visible to the receiver
    check_no_error;
    check_full;

    for (counter[3:0] = 4'h0; counter[3:0] < address_limit[3:0];
                              counter[3:0] = counter[3:0] + 4'h1)
    begin
      if (read_flag_before_data_const)
      begin
        write_submit = 1'b0;
        read_remove = 1'b0;
        do_both_clocks;  // make flags and data visible to the receiver
        check_no_error;
      end

      check_value (in_data[39:0]);
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver

      check_no_error;
    end
    check_empty;
  end
endtask

task overempty_fifo;
  begin
    check_empty;
    write_data[39:0] = 40'hXX_XXXX_XXXX;
    write_submit = 1'b0;
    read_remove = 1'b1;
    do_both_clocks;  // overrun the FIFO this time for sure
    check_read_error;
    check_empty;
  end
endtask

task fill_while_emptying_fifo;
  input  [39:0] in_data;
  reg    [39:0] out_data;
  reg    [3:0] counter;
  begin
    $display ("Fill while Emptying the FIFOs, at time %t", $time);
    out_data[39:0] = in_data[39:0];
    for (counter[3:0] = 4'h0; counter[3:0] < address_limit[3:0];
                              counter[3:0] = counter[3:0] + 4'h1)
    begin
      write_one_fifo_entry (in_data[39:0]);
      check_no_error;
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
    end
    check_full;
// Several possible cases here.  Both sides can either send one data item
//   per clock, or one data item per 2 clocks.  Want to run this sequential
//   code forward so that 2 words are transferred on each port, at whatever speed.
    write_data[39:0] = 40'hXX_XXXX_XXXX;
    check_full;
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;  // make flags and data visible to the receiver
    check_no_error;
    check_full;

    if      ( write_data_before_flag_const &  read_flag_before_data_const) // slow slow
    begin
// Wait, then fetch one word out of FIFO
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and data visible to the receiver
      check_no_error;
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
// Wait, then fetch second word out of FIFO
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and data visible to the receiver
      check_no_error;
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_data[39:0] = in_data[39:0];
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b1;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
      write_one_fifo_entry (in_data[39:0]);
    end
    else if ( write_data_before_flag_const & ~read_flag_before_data_const) // slow fast
    begin
// Immediately fetch first word out of FIFO
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
// Immediately fetch second word out of FIFO
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
      write_one_fifo_entry (in_data[39:0]);
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
      write_one_fifo_entry (in_data[39:0]);
    end
    else if (~write_data_before_flag_const &  read_flag_before_data_const) // fast slow
    begin
// Wait, then fetch one word out of FIFO
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and data visible to the receiver
      check_no_error;
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
// Wait, then fetch second word out of FIFO
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and data visible to the receiver
      check_no_error;
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_data[39:0] = in_data[39:0];
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b1;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
      write_submit = 1'b0;
      read_remove = 1'b0;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
      write_one_fifo_entry (in_data[39:0]);
    end
    else if (~write_data_before_flag_const & ~read_flag_before_data_const) // fast fast
    begin
// Immediately fetch first word out of FIFO
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
// Immediately fetch second word out of FIFO
      check_value (out_data[39:0]);
      out_data[39:0] = out_data[39:0] + 40'h11_1111_1111;
      write_submit = 1'b0;
      read_remove = 1'b1;
      do_both_clocks;  // make flags and maybe data visible to the receiver
      check_no_error;
      write_one_fifo_entry (in_data[39:0]);
      in_data[39:0] = in_data[39:0] + 40'h11_1111_1111;
      write_one_fifo_entry (in_data[39:0]);
    end
    empty_fifo (out_data[39:0]);
  end
endtask

  initial
  begin
    $display ("Checking that Async Reset sets FIFOs to known state, at time %t", $time);
    #5;
    double_sync_write_empty_flag_const = 1'b0;
    double_sync_read_full_flag_const = 1'b0;
    write_data_before_flag_const = 1'b0;
    read_flag_before_data_const = 1'b1;
    write_submit = 1'b0;
    read_remove = 1'b0;
    read_clk = 1'b0;
    write_clk = 1'b0;
    reset_flags_async = 1'b1;
    #5;
    check_empty;
    check_no_error;

    reset_flags_async = 1'b0;
    #5;
    check_empty;
    check_no_error;

    $display ("Checking that FIFOs stay empty when nothing is going on, at time %t", $time);
    do_both_clocks;
    check_empty;
    check_no_error;
    do_both_clocks;
    check_empty;
    check_no_error;
    do_both_clocks;
    check_empty;
    check_no_error;

    write_data_before_flag_const = 1'b1;
    read_flag_before_data_const = 1'b0;
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;
    $display ("Testing with write_data_before_flag_const %h, read_flag_before_data_const %h, at time %t",
              write_data_before_flag_const, read_flag_before_data_const, $time);
    when_empty_write_one_look_for_one_read_data (40'h11_1111_1111);
    when_empty_write_one_look_for_one_read_data (40'h22_2222_2222);
    fill_fifo (40'h44_4444_4444);
    overfill_fifo;
    empty_fifo (40'h44_4444_4444);
    overempty_fifo;
    fill_while_emptying_fifo (40'h44_4444_4444);

    write_data_before_flag_const = 1'b0;
    read_flag_before_data_const = 1'b1;
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;
    $display ("Testing with write_data_before_flag_const %h, read_flag_before_data_const %h, at time %t",
              write_data_before_flag_const, read_flag_before_data_const, $time);
    when_empty_write_one_look_for_one_read_data (40'h11_1111_1111);
    when_empty_write_one_look_for_one_read_data (40'h22_2222_2222);
    fill_fifo (40'h44_4444_4444);
    overfill_fifo;
    empty_fifo (40'h44_4444_4444);
    overempty_fifo;
    fill_while_emptying_fifo (40'h44_4444_4444);

    write_data_before_flag_const = 1'b0;
    read_flag_before_data_const = 1'b0;
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;
    $display ("Testing with write_data_before_flag_const %h, read_flag_before_data_const %h, at time %t",
              write_data_before_flag_const, read_flag_before_data_const, $time);
    when_empty_write_one_look_for_one_read_data (40'h11_1111_1111);
    when_empty_write_one_look_for_one_read_data (40'h22_2222_2222);
    fill_fifo (40'h44_4444_4444);
    overfill_fifo;
    empty_fifo (40'h44_4444_4444);
    overempty_fifo;
    fill_while_emptying_fifo (40'h44_4444_4444);

    $display ("Clocking out last data");
    write_submit = 1'b0;
    read_remove = 1'b0;
    do_both_clocks;
    check_no_error;
    do_both_clocks;
    check_no_error;
    do_both_clocks;
    check_no_error;
    $finish;
  end

  wire   [1:0] fifo_mode =  write_data_before_flag_const ? 2'b01
                         : (read_flag_before_data_const ? 2'b10
                         :  2'b00);

pci_fifo_storage_Nx35 pci_fifo_storage_Nx35 (
  .reset_flags_async          (reset_flags_async),
  .fifo_mode                  (fifo_mode[1:0]),
  .write_clk                  (write_clk),
  .write_sync_clk             (write_clk),
  .write_submit               (write_submit),
  .write_room_available_meta  (write_room_available_meta_35),
  .write_data                 (write_data[34:0]),
  .write_error                (write_error_35),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_clk),
  .read_remove                (read_remove),
  .read_data_available_meta   (read_data_available_meta_35),
  .read_data                  (read_data_35[34:0]),
  .read_error                 (read_error_35)
);

pci_fifo_storage_Nx39 pci_fifo_storage_Nx39 (
  .reset_flags_async          (reset_flags_async),
  .fifo_mode                  (fifo_mode[1:0]),
  .write_clk                  (write_clk),
  .write_sync_clk             (write_clk),
  .write_submit               (write_submit),
  .write_room_available_meta  (write_room_available_meta_39),
  .write_data                 (write_data[38:0]),
  .write_error                (write_error_39),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_clk),
  .read_remove                (read_remove),
  .read_data_available_meta   (read_data_available_meta_39),
  .read_data                  (read_data_39[38:0]),
  .read_error                 (read_error_39)
);

pci_fifo_storage_Nx40 pci_fifo_storage_Nx40 (
  .reset_flags_async          (reset_flags_async),
  .fifo_mode                  (fifo_mode[1:0]),
  .write_clk                  (write_clk),
  .write_sync_clk             (write_clk),
  .write_submit               (write_submit),
  .write_room_available_meta  (write_room_available_meta_40),
  .write_data                 (write_data[39:0]),
  .write_error                (write_error_40),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_clk),
  .read_remove                (read_remove),
  .read_data_available_meta   (read_data_available_meta_40),
  .read_data                  (read_data_40[39:0]),
  .read_error                 (read_error_40)
);
endmodule



