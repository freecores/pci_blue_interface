//===========================================================================
// $Id: reminders.v,v 1.4 2001-03-05 09:54:48 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  A list of things to check before final release.
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
// This code was developed using Verilogger Pro, by Synapticad.
// Their support is greatly appreciated.
//
// NOTE:  The PCI Spec requires a special pad driver.
//        It must have slew rate control and diode clamps.
//        The final chip must have 0 nSec hold time, with
//        respect to the clock input, as detailed in the
//        PCI Spec 2.2 section 7.6.4.2.
//
// NOTE:  This IO pad is motivated by personal experience
//        with timing problems in 3000 series Xilinx chips.
//        The later Xilinx chips incorporate flops on the
//        data and OE signals in the IO pads, instead of
//        immediately adjacent to them.  This module does
//        not require that the flops be in the pad.  However,
//        the user of this IO pad assumes that the flops are
//        either in or very near to the IO pads.
//
// NOTE:  The PCI Bus clock can operate from 0 Hz to 33.334 MHz.
//        The 0 Hz requirement means that the controller must be
//        able to respond to a Reset when the clock is not
//        operating.  These OP Pads and their associated flops
//        must go High-Z immediately upon seeing a PCI Reset,
//        and may NOT stay driven until the next clock edge.
//        Async resets on the OE flops are absolutely required.  
//
//===========================================================================
// reminders about ideas and issues:
// Write to config register must complete before next ref is allowed,
//  because write might change base address or operating mode
// Address Par Err, Data Par Err, Master Abort must be indicated to
//  Config register before the next read is allowed
// Address stepping required on Config Refs.  See section 3.2.2.3.5
// Host can start a read or write at the same time the bus starts a Read
//  or a write.  In fact, bus can start a Read THEN a write.
// Data from bus can either be read data returned to host or write data
//  originating on Bus.
// Data from host can either be Read Data returned to Bus or write data
//  originating at Host.
// Possibly 3 fifos can work:  Host Write/Command, Bus Read,
//  Host Read/Bus Write.  Check ordering rules!
// Host Read Fifo would contain this info:
//  1 bit indicating Host Read/Bus Write indication
//  1 bit indicating Address Phase
//  1 bit indicating last in packet (same as above?)
//  32 bits of A/D data
//  4 bits of CBE data
//  1 bit of Parity data
// Remember to disconnect on Base Address boundries
// Latency TImer in Master ticks when Grant not asserted
// Remember to deassert Req for 2 clocks upon errors
// remember that a master abort happens 8 clocks after Frame L
// Remember that fast back-to-back references can happen with no idle cycle inbetween
// Remember that there is an initial data latency, and you have to do a
//  retry if you can't produce data within that latency
// remember that this initial latency counts for both read and write
// remember that delayed reads have a 2**15 discard timer
// remember that Special cycles and interrupt references end with a master abort
// remember that Config cycles through a bridge might end without a master abort,
//   even if the reference DID end with a master abort onthe target bus.
//   How should writes be dealt with?
// remember that Config References must be replied to if the Subdevice is
//  implemented, but NOT if it is not.
// remember that subsevices can be allocated in any order
// remember that the Bus interface is only allowed to write certain bits,
//  and the host interface can write others

