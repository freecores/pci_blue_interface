//===========================================================================
// $Id: plesiochronous_fifo.v,v 1.2 2001-08-26 11:12:19 bbeaver Exp $
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
//          the FIFO on adjacent Sender-side clocks.
//
// NOTE:  This FIFO REQUIRES that the Receiver ALWAYS receives a full packet
//          out of the FIFO as soon as it gets an indication that the FIFO
//          is half full.
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
//        As long as there are bounds on the bounds on the variations of the
//          sender's N MHz clock and the receiver's N/2 MHz clock, the system
//          can be considered to be plesiochronous.
//
// NOTE:  The idea:  The Sender writes data into the FIFO.  Every so often,
//          the sender intentionally does not write to the FIFO for 1 clock.
//        The Receiver watches the FIFO.  The receiver does not START reading
//          from the FIFO until the FIFO becomes half full.
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
//          empty the FIFO before it finishes reading a packet.
//        As soon as the Receiver finishes reading a packet, it waits until
//          the FIFO gets at least half full again.  The wait may be for
//          more than 1 clock.  The waits until the FIFO is half full keeps
//          the Receiver from emptying the FIFO inthe ling run.
//          
// NOTE:  You have to tell the FIFO the paramaters of the clocks and packets
//          you are designing for.  This lets the FIFO calculate whether it
//          can safely meet the design goals.
//
// NOTE:  In this case, the FIFO is ALWAYS 5 elements deep.  I don't know if
//          this will be enough in real life.  Depends on the clocks.
//
//===========================================================================

`timescale 1ns/1ps

module plesiochronous_fifo (
  reset_flags_async,
  write_clk, write_sync_clk,
  write_submit,
  write_data,
  read_clk, read_sync_clk,
  read_fifo_half_full,
  read_data
);

  parameter TRANSMIT_CLOCK_UNCERTAINTY_PARTS_PER_MILLION  = 0;  // typically 100
  parameter RECEIVE_CLOCK_UNCERTAINTY_PARTS_PER_MILLION   = 0;  // typically 100
  parameter NUMBER_OF_CLOCKS_BETWEEN_PACKET_BOUNDRIES     = 0;  // might be 256, for instance
  parameter TRANSMIT_CLOCK_DIVIDED_BY_RECEIVE_CLOCK_RATIO = 0;  // must be 1 now
  parameter TRANSMIT_FIFO_WIDTH                           = 0;
  parameter RECEIVE_FIFO_WIDTH                            = 0;

  input   reset_flags_async;
  input   write_clk, write_sync_clk;
  input   write_submit;
  input  [TRANSMIT_FIFO_WIDTH:0] write_data;
  input   read_clk, read_sync_clk;
  output  read_fifo_half_full;
  output [RECEIVE_FIFO_WIDTH:0] read_data;

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
    if (NUMBER_OF_CLOCKS_BETWEEN_PACKET_BOUNDRIES <= 0)
    begin
      $display ("*** Exiting because %m NUMBER_OF_CLOCKS_BETWEEN_PACKET_BOUNDRIES %d <= 0",
                   NUMBER_OF_CLOCKS_BETWEEN_PACKET_BOUNDRIES);
      $finish;
    end
    if (TRANSMIT_CLOCK_DIVIDED_BY_RECEIVE_CLOCK_RATIO != 1)
    begin
      $display ("*** Exiting because %m TRANSMIT_CLOCK_DIVIDED_BY_RECEIVE_CLOCK_RATIO %d != 1",
                   TRANSMIT_CLOCK_DIVIDED_BY_RECEIVE_CLOCK_RATIO);
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
  end
// synopsys translate_on
endmodule


