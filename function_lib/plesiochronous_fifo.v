//===========================================================================
// $Id: plesiochronous_fifo.v,v 1.3 2001-08-29 11:30:58 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Web definition of Plesiochronous:
// "Signals which are arbitrarily close in frequency to some defined precision.
//  They are not sourced from the same clock and so, over the long term, will
//  be skewed from each other.  Their relative closeness of frequency allows a
//  switch to cross connect, switch, or in some way process them.  That same
//  inaccuracy of timing will force a switch, over time, to repeat or delete
//  frames (called frame slips) in order to handle buffer underflow or overflow."
//
// Summary:  Make a FIFO which is used to cross between 2 Pleasiochronous
//             clock domains.
//           This code assumes that latency does not matter.
//           This code assumes that the reader of the FIFO needs to read an
//             entire packet in back-to-back clocks, with no dead cycles.
//           This code REQUIRES that the writer of the FIFO leaves dead cycles
//             when writing the FIFO, so that it does not overflow.
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
// NOTE:  This FIFO REQUIRES that the Sender ALWAYS sends a full packet into
//          the FIFO on adjacent Sender-side clocks.  NO WAIT STATES except at
//          packet boundries.  The Sender promises this to the Receiver.
//
// NOTE:  This FIFO REQUIRES that the Receiver ALWAYS receives a full packet
//          out of the FIFO as soon as it gets an indication that the FIFO
//          is half full.  NO WAIT STATES.  The Receiver promises this to
//          the Sender.
//
// NOTE:  The Read side has to capture the Read Data IMMEDIATELY.  It must
//          wrap read_fifo_half_full back directly to read_consume, and must
//          capture and use the data it captures the first clock read_consume
//          is asserted.  read_consume means data valid to the receiver logic.
//
// NOTE:  A plesiochronous system is one in which the different clock domains
//          are running at different frequencies, but the designer knows how
//          far apart the system frequencies are worst case.  The designer
//          can use this knowledge to make the system seem fully synchronous.
//
// NOTE:  The system does NOT need to have the same frequencies for both the
//          reader and the writer, if the widths of the interfaces are different.
//        For instance, assume that the sender runs at N MHz with an M bit
//          interface.  The receiver might run at N/2 MHz with a 2*M bit
//          interface.
//        As long as there are bounds on the variations of the sender's N MHz
//          clock and the receiver's N/2 MHz clock, the system can be
//          considered to be plesiochronous.
//
// NOTE:  The idea:  The Sender writes data into the FIFO.  Every so often,
//          BUT ONLY AT A PACKET BOUNDRY, the sender intentionally does not
//          write to the FIFO for 1 clock.
//        The Receiver watches the FIFO.  The receiver does not START reading
//          from the FIFO until the FIFO becomes half full.  Once it starts
//          reading, it removes an entire packet from the FIFO all at once.
//        The Sender can be sure that it will not overrun the FIFO, because
//          it knows that the Receiver is emptying it.  Even if the Sender is
//          filling faster than the Receiver is emptying, the bounded
//          difference in frequencies lets the Sender know that it cannot
//          fill up the FIFO before it skips a write.
//        The skipped write cycle keeps the Sender from over-filling the
//          FIFO in the long run.
//        The Receiver knows that it can receive an entire packet from the
//          FIFO without emptying it.  Even if the Receiver is emptying the
//          FIFO faster than the Sender is filling it, the bounded
//          difference in frequencies lets the Receiver know that it cannot
//          empty the FIFO before it finishes reading a full packet.
//        As soon as the Receiver finishes reading a packet, it waits until
//          the FIFO gets at least half full again.  The wait may be for
//          more than 1 clock.  The waits until the FIFO is half full keeps
//          the Receiver from emptying the FIFO inthe ling run.
//          
// NOTE:  You have to tell the FIFO the paramaters of the clocks and packets
//          you are designing for.  This lets the FIFO calculate whether it
//          can safely meet the design goals.
//
// NOTE:  In this case, the FIFO is ALWAYS 6 elements deep.  There are 6 entries
//          instead of 4 to handle cases I can't imagine involving clock jitter.
//
//===========================================================================

`timescale 1ns/1ps

module plesiochronous_fifo (
  reset_flags_async,
  write_clk,
  write_submit,
  write_data,
  read_clk, read_sync_clk,
  read_fifo_half_full,
  read_consume,
  read_data
);

// These parameters MUST be set where the module is instantiated.
  parameter TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION  = 0;  // typically 100
  parameter RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION   = 0;  // typically 100
  parameter NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET          = 0;  // might be 256, for instance
  parameter TRANSMIT_FIFO_WIDTH                           = 0;  // MUST be the same as RECEIVE_FIFO_WIDTH now
  parameter RECEIVE_FIFO_WIDTH                            = 0;

  input   reset_flags_async;
  input   write_clk;
  input   write_submit;
  input  [TRANSMIT_FIFO_WIDTH - 1 : 0] write_data;
  input   read_clk, read_sync_clk;  // The read_sync_clock is the SAME as the read_clk
  output  read_fifo_half_full;
  input   read_consume;
  output [RECEIVE_FIFO_WIDTH - 1 : 0] read_data;

// Calculate paramaters based on the main parameters set by the user.
  parameter WORSE_CASE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION =
                    RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION
                  + TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION;

  parameter TRANSMIT_CLOCK_DIVIDED_BY_RECEIVE_CLOCK_RATIO =
                    TRANSMIT_FIFO_WIDTH/RECEIVE_FIFO_WIDTH;  // must be 1 now

  parameter TRANSMIT_FIFO_CLOCK_SLIP_DEPTH =
                    1000000/WORSE_CASE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION;

function [2:0] grey_code_counter_inc;
  input  [2:0] grey_code_counter_in;
  begin
    case (grey_code_counter_in[2:0])
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
          $display ("*** %m grey code in to inc has invalid value %h, at %t",
                                        grey_code_counter_in[2:0], $time);
        end
        else ;  // be quiet linterizer
// synopsys translate_off
      end
    endcase
  end
endfunction

function [2:0] grey_to_binary_3;
  input  [2:0] grey_code_counter_in;
  begin
    case (grey_code_counter_in[2:0])
    3'b000: grey_to_binary_3[2:0] = 3'b000;
    3'b001: grey_to_binary_3[2:0] = 3'b001;
    3'b011: grey_to_binary_3[2:0] = 3'b010;
    3'b010: grey_to_binary_3[2:0] = 3'b011;
    3'b110: grey_to_binary_3[2:0] = 3'b100;
    3'b111: grey_to_binary_3[2:0] = 3'b101;
    3'b101: grey_to_binary_3[2:0] = 3'b110;
    3'b100: grey_to_binary_3[2:0] = 3'b111;
    default:
      begin
        grey_to_binary_3[2:0] = 3'b000;
// synopsys translate_off
        if ($time > 0)
        begin
          $display ("*** %m grey code in to binary has invalid value %h, at %t",
                                        grey_to_binary_3[2:0], $time);
        end
        else ;  // be quiet linterizer
// synopsys translate_off
      end
    endcase
  end
endfunction

// Write-side FIFO counters
  reg [2:0] write_pointer_grey_W;    // counts 0, 1, 3, 2, 6, 7, 5, 4, 0, 1, ... 
  reg [2:0] write_pointer_physical;  // counts 0, 1, 2, 3, 4, 0, 1, ...

  always @(posedge write_clk or posedge reset_flags_async)
  begin
    if (reset_flags_async == 1'b1)
    begin
      write_pointer_grey_W[2:0] <= 3'h0;
      write_pointer_physical[2:0] <= 3'h0;
    end
    else
    begin
      if (write_submit == 1'b1)
      begin
        write_pointer_grey_W[2:0] <= grey_code_counter_inc (write_pointer_grey_W[2:0]);
        write_pointer_physical[2:0] <= (write_pointer_physical[2:0] >= 3'h5)
                                     ? 3'h0
                                     : write_pointer_physical[2:0] + 3'h1;
      end
      else
      begin
        write_pointer_grey_W[2:0] <= write_pointer_grey_W[2:0];
        write_pointer_physical[2:0] <= write_pointer_physical[2:0];
      end
    end
  end

// Read-side FIFO counters
  reg [2:0] read_pointer_grey;    // counts 0, 1, 3, 2, 6, 7, 5, 4, 0, 1, ... 
  reg [2:0] read_pointer_physical;  // counts 0, 1, 2, 3, 4, 0, 1, ...

  always @(posedge read_clk or posedge reset_flags_async)
  begin
    if (reset_flags_async == 1'b1)
    begin
      read_pointer_grey[2:0] <= 3'h0;
      read_pointer_physical[2:0] <= 3'h0;
    end
    else
    begin
      if (read_consume == 1'b1)
      begin
        read_pointer_grey[2:0] <= grey_code_counter_inc (read_pointer_grey[2:0]);
        read_pointer_physical[2:0] <= (read_pointer_physical[2:0] >= 3'h5)
                                     ? 3'h0
                                     : read_pointer_physical[2:0] + 3'h1;
      end
      else
      begin
        read_pointer_grey[2:0] <= read_pointer_grey[2:0];
        read_pointer_physical[2:0] <= read_pointer_physical[2:0];
      end
    end
  end

// NOTE:  Very unusual FIFO.  It needs to synchronize the Write Pointer into
//          the Read clock domain, but does NOT need to synchronize the Read
//          Pointer into the Write clock domain.  The Writer KNOWS that it
//          can always safely write.  This is guaranteed by the Read side
//          behavior.  That Read side is GUARANTEED to always be reading.

  wire   [2:0] write_pointer_grey_sync_R;

synchronizer_flop sync_write_grey_0 (
  .data_in                    (write_pointer_grey_W[0]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (write_pointer_grey_sync_R[0]),
  .async_reset                (reset_flags_async)
);

synchronizer_flop sync_write_grey_1 (
  .data_in                    (write_pointer_grey_W[1]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (write_pointer_grey_sync_R[1]),
  .async_reset                (reset_flags_async)
);

synchronizer_flop sync_write_grey_2 (
  .data_in                    (write_pointer_grey_W[2]),
  .clk_out                    (read_sync_clk),
  .sync_data_out              (write_pointer_grey_sync_R[2]),
  .async_reset                (reset_flags_async)
);

// Calculate how much stuff is stored in the FIFO.  This can be
//   done by comparing the Read and Write Grey Code Counters.
// They start out the same.  The Write side gets ahead of
//   the read side, until the read side starts unloading.
// If the write side stops writing, they can get to be the
//   same again.
// These counters wrap.  In the case that the Write Counter is
//   greater than than the Read Counter, the amount of stuff
//   in the FIFO is write pointer - read pointer;
// In the case that the Write Counter is less than the Read
//   Counter, the amount of stuff in the FIFO is 8 + difference.
//   BUT only the bottom 3 bits matter!  That seems to mean
//   that you can simply subtract and look at the bottom 3 bits.

  wire   [2:0] write_pointer_binary_R =
                  grey_to_binary_3 (write_pointer_grey_sync_R[2:0]);

  wire   [2:0] read_pointer_binary =
                  grey_to_binary_3 (read_pointer_grey[2:0]);

  wire   [2:0] number_of_elements_in_fifo =
                  write_pointer_binary_R[2:0] - read_pointer_binary[2:0];

// Tell the Receiver to go when there are 2 or more elements in this 5 element FIFO.
  assign  read_fifo_half_full = number_of_elements_in_fifo[2:0] >= 3'h3;

// FIFO storage
  reg    [TRANSMIT_FIFO_WIDTH - 1 : 0] fifo_0;
  reg    [TRANSMIT_FIFO_WIDTH - 1 : 0] fifo_1;
  reg    [TRANSMIT_FIFO_WIDTH - 1 : 0] fifo_2;
  reg    [TRANSMIT_FIFO_WIDTH - 1 : 0] fifo_3;
  reg    [TRANSMIT_FIFO_WIDTH - 1 : 0] fifo_4;
  reg    [TRANSMIT_FIFO_WIDTH - 1 : 0] fifo_5;

  always @(posedge write_clk)
  begin
    fifo_0[TRANSMIT_FIFO_WIDTH - 1 : 0] =
                    (write_submit & (write_pointer_physical[2:0] == 3'h0))
                  ? write_data[TRANSMIT_FIFO_WIDTH - 1 : 0]
                  : fifo_0[TRANSMIT_FIFO_WIDTH - 1 : 0];
    fifo_1[TRANSMIT_FIFO_WIDTH - 1 : 0] =
                    (write_submit & (write_pointer_physical[2:0] == 3'h1))
                  ? write_data[TRANSMIT_FIFO_WIDTH - 1 : 0]
                  : fifo_1[TRANSMIT_FIFO_WIDTH - 1 : 0];
    fifo_2[TRANSMIT_FIFO_WIDTH - 1 : 0] =
                    (write_submit & (write_pointer_physical[2:0] == 3'h2))
                  ? write_data[TRANSMIT_FIFO_WIDTH - 1 : 0]
                  : fifo_2[TRANSMIT_FIFO_WIDTH - 1 : 0];
    fifo_3[TRANSMIT_FIFO_WIDTH - 1 : 0] =
                    (write_submit & (write_pointer_physical[2:0] == 3'h3))
                  ? write_data[TRANSMIT_FIFO_WIDTH - 1 : 0]
                  : fifo_3[TRANSMIT_FIFO_WIDTH - 1 : 0];
    fifo_4[TRANSMIT_FIFO_WIDTH - 1 : 0] =
                    (write_submit & (write_pointer_physical[2:0] == 3'h4))
                  ? write_data[TRANSMIT_FIFO_WIDTH - 1 : 0]
                  : fifo_4[TRANSMIT_FIFO_WIDTH - 1 : 0];
    fifo_5[TRANSMIT_FIFO_WIDTH - 1 : 0] =
                    (write_submit & (write_pointer_physical[2:0] == 3'h5))
                  ? write_data[TRANSMIT_FIFO_WIDTH - 1 : 0]
                  : fifo_5[TRANSMIT_FIFO_WIDTH - 1 : 0];
  end

// Read port to FIFO
  assign  read_data = ({RECEIVE_FIFO_WIDTH{read_pointer_physical[2:0] == 3'h0}}
                                          & fifo_0[TRANSMIT_FIFO_WIDTH - 1 : 0])
                    | ({RECEIVE_FIFO_WIDTH{read_pointer_physical[2:0] == 3'h1}}
                                          & fifo_1[TRANSMIT_FIFO_WIDTH - 1 : 0])
                    | ({RECEIVE_FIFO_WIDTH{read_pointer_physical[2:0] == 3'h2}}
                                          & fifo_2[TRANSMIT_FIFO_WIDTH - 1 : 0])
                    | ({RECEIVE_FIFO_WIDTH{read_pointer_physical[2:0] == 3'h3}}
                                          & fifo_3[TRANSMIT_FIFO_WIDTH - 1 : 0])
                    | ({RECEIVE_FIFO_WIDTH{read_pointer_physical[2:0] == 3'h4}}
                                          & fifo_4[TRANSMIT_FIFO_WIDTH - 1 : 0])
                    | ({RECEIVE_FIFO_WIDTH{read_pointer_physical[2:0] == 3'h5}}
                                          & fifo_5[TRANSMIT_FIFO_WIDTH - 1 : 0]);

// synopsys translate_off
// ASSUMING that the clock period is 10 nSec, look to make sure data is valid long
//   enough to get through the read MUX.  At least 1 write clock period!
  reg     written_0, written_1, written_2, written_3, written_4, written_5;
  reg     valid_0, valid_1, valid_2, valid_3, valid_4, valid_5;
  initial
  begin
    written_0 = 1'b0;
    written_1 = 1'b0;
    written_2 = 1'b0;
    written_3 = 1'b0;
    written_4 = 1'b0;
    written_5 = 1'b0;
  end
  always @(posedge write_clk)
  begin
    written_0 <= (write_submit & (write_pointer_physical[2:0] == 3'h0)) ^ written_0;  // only change when written
    valid_0 <= written_0;
    written_1 <= (write_submit & (write_pointer_physical[2:0] == 3'h1)) ^ written_1;
    valid_1 <= written_1;
    written_2 <= (write_submit & (write_pointer_physical[2:0] == 3'h2)) ^ written_2;
    valid_2 <= written_2;
    written_3 <= (write_submit & (write_pointer_physical[2:0] == 3'h3)) ^ written_3;
    valid_3 <= written_3;
    written_4 <= (write_submit & (write_pointer_physical[2:0] == 3'h4)) ^ written_4;
    valid_4 <= written_4;
    written_5 <= (write_submit & (write_pointer_physical[2:0] == 3'h5)) ^ written_5;
    valid_5 <= written_5;
  end
  always @(posedge read_clk)
  begin
    if (read_consume & (read_pointer_physical[2:0] == 3'h0) & (written_0 ^ valid_0))
      $display ("*** read data 0 not valid for full read clock at %t", $time);
    if (read_consume & (read_pointer_physical[2:0] == 3'h1) & (written_1 ^ valid_1))
      $display ("*** read data 1 not valid for full read clock at %t", $time);
    if (read_consume & (read_pointer_physical[2:0] == 3'h2) & (written_2 ^ valid_2))
      $display ("*** read data 2 not valid for full read clock at %t", $time);
    if (read_consume & (read_pointer_physical[2:0] == 3'h3) & (written_3 ^ valid_3))
      $display ("*** read data 3 not valid for full read clock at %t", $time);
    if (read_consume & (read_pointer_physical[2:0] == 3'h4) & (written_4 ^ valid_4))
      $display ("*** read data 4 not valid for full read clock at %t", $time);
    if (read_consume & (read_pointer_physical[2:0] == 3'h5) & (written_5 ^ valid_5))
      $display ("*** read data 5 not valid for full read clock at %t", $time);
  end

// Check that there is never more than 5 words in this FIFO.  I know, that
//   means there only needs to be 5 sets of flops!
// Remember that there MIGHT be more data in the FIFO than the receive side
//   thinks, because the Write Pointer might not have been incremented.  Also,
//   due to jitter, the Write side might get 2 writes (!) in between any 2
//   adjacent Read side clocks.  This MIGHT mean that the data can go from
//   having 3 entry in it to having 5 entries.  Then, as the write clock
//   contiues to run fast, the FIFO might work up to having 6 full entries.
// The other excuse I can have to having the extra set of flops is that it
//   makes it clear that hold times are met, even when a write happens at
//   the exact same time as the read which frees up the 5th entry.
// I feel much more confident with a 6th available entry.

  always @(posedge read_clk)
  begin
    if (number_of_elements_in_fifo[2:0] >= 3'h6)
      $display ("*** %m fatal plesiochronous FIFO got too much data in it at %t", $time);
  end
// synopsys translate_on

// synopsys translate_off
  initial
  begin
    if (TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION <= 0)
    begin
      $display ("*** Exiting because %m TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION %d <= 0",
                   TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION);
      $finish;
    end
    if (RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION <= 0)
    begin
      $display ("*** Exiting because %m RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION %d <= 0",
                   RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION);
      $finish;
    end
    if (NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET <= 0)
    begin
      $display ("*** Exiting because %m NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET %d <= 0",
                   NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET);
      $finish;
    end
    if (TRANSMIT_FIFO_WIDTH <= 0)
    begin
      $display ("*** Exiting because %m TRANSMIT_FIFO_WIDTH %d <= 0",
                   TRANSMIT_FIFO_WIDTH);
      $finish;
    end
    if (RECEIVE_FIFO_WIDTH <= 0)
    begin
      $display ("*** Exiting because %m RECEIVE_FIFO_WIDTH %d <= 0",
                   RECEIVE_FIFO_WIDTH);
      $finish;
    end
// NOTE: WORKING: Remove this restriction when this becomes able to write
//                  data with a different width than the read data port is.
//                This will require the clocks to run at the ratio set by
//                  the rations of the FIFO port widths!
    if (TRANSMIT_FIFO_WIDTH != RECEIVE_FIFO_WIDTH)
    begin
      $display ("*** Exiting because %m TRANSMIT_FIFO_WIDTH != RECEIVE_FIFO_WIDTH %d <= 0",
                   TRANSMIT_FIFO_WIDTH, RECEIVE_FIFO_WIDTH);
      $finish;
    end

// The Sender needs to know that it will not overrun the FIFO even if it is running
//   faster than the Receiver.  It needs to make careful calculations to make sure
//   this is true.
// It knows that the Receiver won't start unloading until it thinks the FIFO is
//   at least 1/2 full.  But when is the latest this can happen?
// The latest is when the Sender writes word 0, then word 1, BUT the indication
//   that word 1 is available does not get latched by the receiver until the
//   NEXT clock.  At that time, the Sender writes entry 2.
// The Receiver unloads data from word 0 at the same time the sender writes word 3.
//   So the FIFO has valid data in locations 1, 2, and 3.
// The FIFO has 3 valid words in it at the start.
// If the Sender writes faster than the Receiver reads, the FIFO can work up to
//   having 4 words of valid data in it.
//
// The Receiver needs to know that it will not run out of data if it unloads
//   faster than the Sender sends.  How can it check this?
// The earliest the Receiver can know that data is available is if the Sender
//   writes word 0, the word 1, and the Receiver hears about the data available
//   instantly.  Then, the Sender writes word 2 while the receiver unloads word 0.
//   So the FIFO has valid data in locations 1 and 2.
// The FIFO has 2 words of data in it at the start.
// If the Receiver reads faster than the Sender writes, the FIFO can work down to
//   having 1 word of valid data in it.
//
// Having 4 words max and 1 word min are fine constraints on the FIFO's behavior.
// To meet the constraints, the Sender and Receiver clocks must not vary too far
//   from one-another.  If they got too far apart, too much data would be either
//   read or written throught the FIFO.

// Calculate the maximum clock difference possible.
// NOTE:  This calculation will have to take into account different port widths
//   with corresponding different port clocks, if and when this is improved to
//   allow port size changes across the FIFO.

    if (TRANSMIT_FIFO_CLOCK_SLIP_DEPTH < NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET)
    begin
      $display ("*** Exiting because %m TRANSMIT_FIFO_CLOCK_SLIP_DEPTH %d < NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET %d",
                   TRANSMIT_FIFO_CLOCK_SLIP_DEPTH, NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET);
      $finish;
    end
  end
// synopsys translate_on
endmodule

// synopsys translate_off
// If the vendor has a flop which is particularly good at settling out of
//   metastability, it should be used here.
module synchronizer_flop (
  data_in, clk_out, sync_data_out, async_reset
);
  input   data_in;
  input   clk_out;
  output  sync_data_out;
  input   async_reset;

  reg     sync_data_out;

  always @(posedge clk_out or posedge async_reset)
  begin
    if (async_reset == 1'b1)
    begin
      sync_data_out <= 1'b0;
    end
    else
    begin
      sync_data_out <= data_in;
    end
  end
endmodule
// synopsys translate_on

// `define TEST_PLESIOCHRONOUS_FIFO
`ifdef TEST_PLESIOCHRONOUS_FIFO
module test_plesiochronous_fifo;
// Plan: do a bunch of packets when the Write Clock is faster than the Read Clock
// Then do a bunch of packets when the Read Clock is faster than the Write Clock
//
// Experiment with small clock deltas to change event ordering.
// Print out at run time when the receiver is slipping clocks
// Check that data is strictly incrementing; no drops or repeats
  real    transmit_clock_period, receive_clock_period;
  real    transmit_clock_delta, receive_clock_delta;
  integer packet_length;
  integer packets_to_send;
  integer i, j, k, l;

  reg     reset_flags_async;
  reg     write_clk;
  reg     write_submit;
  reg    [31:0] write_data;
  reg     read_clk;
  wire    read_fifo_half_full;
  reg     read_consume;
  reg    [31:0] expected_read_data;
  wire   [31:0] read_data;

task read_one_item;
  begin
    #0;
    read_clk = 1'b1;
    #receive_clock_period;
    read_clk = 1'b0;
    #receive_clock_period;
  end
endtask

task write_one_item;
  begin
    #0;
    write_clk = 1'b1;
    #transmit_clock_period;
    write_clk = 1'b0;
    #transmit_clock_period;
  end
endtask

task send_and_check;
  begin
  fork  // Write Clock faster than Read Clock
    begin  // transmit activity
      write_clk = 1'b0;
      reset_flags_async = 1'b1;
      # 10;
      reset_flags_async = 1'b0;
      # 10;
      # transmit_clock_delta;
      write_data[31:0] = 32'h00000000;
      for (i = 0; i < packets_to_send; i = i + 1)
      begin
        write_submit = 1'b1;
        for (j = 0; j < packet_length; j = j + 1)
        begin
          write_data[31:0] = write_data[31:0] + 32'h00000001;
          write_one_item;  // send 1 data item;
        end
        write_submit = 1'b0;
        write_one_item;  // skip a write;
      end
    end

    begin  // receive activity
      read_clk = 1'b0;
      # 10;
      # 10;
      # receive_clock_delta;
      expected_read_data[31:0] = 32'h00000001;
      for (k = 0; k < packets_to_send; k = k + 1)
      begin
        read_consume = 1'b0;
        if (k == 0)  // wait for the first one
        begin
          while (read_fifo_half_full == 1'b0)
          begin
            read_one_item;  // snooze
          end
        end
        else  // all subsequent ones should be back-to-back.
        begin
          if (read_fifo_half_full == 1'b1)
          begin
            $display ("Reading with 0 delay");
          end
          else
          begin
            read_one_item;  // snooze
            if (read_fifo_half_full == 1'b1)
            begin
              $display ("Reading with 1 delay");
            end
            else
            begin
              read_one_item;  // snooze
              if (read_fifo_half_full == 1'b1)
              begin
                $display ("Reading with 2 delay");
              end
              else
              begin
                read_one_item;  // snooze
                if (read_fifo_half_full == 1'b1)
                begin
                  $display ("Reading with 3 delay");
                end
                else
                begin
                  $display ("*** Data didn't become available!");
                end
              end
            end
          end
        end
        read_consume = 1'b1;  // this is a combinational copy of read_fifo_half_full!
        for (l = 0; l < packet_length; l = l + 1)
        begin
          if (expected_read_data[31:0] !== read_data[31:0])
          begin
            $display ("*** Data wasn't as expected! %h %h",
                        read_data[31:0], expected_read_data[31:0]);
          end
          read_one_item;
          expected_read_data[31:0] = expected_read_data[31:0] + 32'h0000001;
        end
      end
    end
  join
  end
endtask

  real    normal_clk, fast_clk, slow_clk;

initial
  begin
  packet_length = 20;  // needed if each clock varies <= 25000 parts per million
  packets_to_send = 200;
  normal_clk = 5.0;
  fast_clk = normal_clk * 0.976;  // FAILS if 9.75, 1.025 !?!
  slow_clk = normal_clk * 1.024;

  $display ("Same Frequency, no offset");
  transmit_clock_period = normal_clk;
  receive_clock_period = normal_clk;
  transmit_clock_delta = 0.000;
  receive_clock_delta = 0.000;

  send_and_check;

  $display ("Same Frequency, Transmit late");
  transmit_clock_period = normal_clk;
  receive_clock_period = normal_clk;
  transmit_clock_delta = 0.001;
  receive_clock_delta = 0.000;

  send_and_check;

  $display ("Same Frequency, Receive late");
  transmit_clock_period = normal_clk;
  receive_clock_period = normal_clk;
  transmit_clock_delta = 0.000;
  receive_clock_delta = 0.001;

  send_and_check;


  $display ("Transmit Fast, no offset");
  transmit_clock_period = fast_clk;
  receive_clock_period = slow_clk;
  transmit_clock_delta = 0.000;
  receive_clock_delta = 0.000;

  send_and_check;

  $display ("Transmit Fast, Transmit late");
  transmit_clock_period = fast_clk;
  receive_clock_period = slow_clk;
  transmit_clock_delta = 0.001;
  receive_clock_delta = 0.000;

  send_and_check;

  $display ("Transmit Fast, Receive late");
  transmit_clock_period = fast_clk;
  receive_clock_period = slow_clk;
  transmit_clock_delta = 0.000;
  receive_clock_delta = 0.001;

  send_and_check;


  $display ("Receive Fast, no offset");
  transmit_clock_period = slow_clk;
  receive_clock_period = fast_clk;
  transmit_clock_delta = 0.000;
  receive_clock_delta = 0.000;

  send_and_check;

  $display ("Receive Fast, Transmit late");
  transmit_clock_period = slow_clk;
  receive_clock_period = fast_clk;
  transmit_clock_delta = 0.001;
  receive_clock_delta = 0.000;

  send_and_check;

  $display ("Receive Fast, Receive late");
  transmit_clock_period = slow_clk;
  receive_clock_period = fast_clk;
  transmit_clock_delta = 0.000;
  receive_clock_delta = 0.001;

  send_and_check;

  end


// Instantiation parameters are in order:
//  TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION
//  RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION
//  NUMBER_OF_TRANSMIT_CLOCKS_PER_PACKET
//  TRANSMIT_FIFO_WIDTH
//  RECEIVE_FIFO_WIDTH

plesiochronous_fifo #(25000, 25000, 20, 32, 32) test_fifo (
  .reset_flags_async          (reset_flags_async),
  .write_clk                  (write_clk),
  .write_submit               (write_submit),
  .write_data                 (write_data[31:0]),
  .read_clk                   (read_clk),
  .read_sync_clk              (read_clk),
  .read_fifo_half_full        (read_fifo_half_full),
  .read_consume               (read_consume),
  .read_data                  (read_data[31:0])
);
`endif  // TEST_PLESIOCHRONOUS_FIFO
endmodule


