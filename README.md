fldigi-ruby
===========

fldigi-ruby is a ruby gem for interfacing with the FLDigi API.  The
intent is to be able to use fldigi as a radio modem from ruby scripts
(though it's useful for other tasks, as well, such as changing
frequencies on a schedule, fetching the current radio frequency, etc).

The FLDigi API is only very lightly documented (basically one sentence
of explanation per API call), and there is essentially zero client
source on the Internet to use as a reference (ie, to steal from)
beyond what's shipped with FLDigi, so this code is a result of doing a
lot of reading of the FLDigi source combined with a bunch of trial and
error.  What little documentation I can find is here:

http://www.w1hkj.com/FldigiHelp-3.22/xmlrpc-control.html

To use the API, you'll first need to require it:

require 'fldigi'

Next, connect to fldigi.  There are three parameters that can be
supplied here.  The simplest is to supply no parameters, which makes
the assumption that fldigi is running on the default port on the same
host that this script is running on (ie, localhost/127.0.0.1), and
that you've configured both FLDigi and your radio for remote control
of frequency, mode, etc:

fldigi=Fldigi.new()

If you have not wired and configured your radio for remote control, do
this, instead:

fldigi=Fldigi.new(false)

You can also optionally supply an IP address and a port number if
you're trying to control FLDigi on another host or on a nonstandard
port.

The variable 'fldigi' is now your "handle" for talking to FLDigi.  Be
aware that FLDigi does some semi-illegal things with XMLRPC, including
sometimes returning 'nil' as a result.  This is not uncommon, but
technically not allowed by the standard.  So you have to tell ruby to
allow for this deviation:

XMLRPC::Config::ENABLE_NIL_PARSER=true

Most parameters within the object default to something sane at the
time of creation, but there are a few things you might want to set.
Be aware that the fldigi gem works by keeping an internal state, then
"pushing" that state to the radio when requested.  Though some
commands trigger an immediate API call to FLDigi, most manipulate
internal object state, which does not affect the radio until you
"sync" them.  Let's set up some state (even though some of these are
already defaulted to the values we're setting):

# Choose the PSK31 modem.
fldigi.modem="BPSK31"

# Use a carrier frequency of 1khz (the "sweet spot" in most radios).
fldigi.carrier=1000

# Set the dial frequency to 14.07mhz (final xmt freq is dial+carrier, or 14.071mhz).
fldigi.dial_freq=14070000

# Turn on squelch.
fldigi.squelch=true

# Set the squelch value to 3.0 (reasonable for most radios).
fldigi.slevel=3.0

# Turn on AFC.
fldigi.afc=true

Note that at this point, nothing on the radio has actually changed
(nor has anything in the FLDigi program).  All we've done is to
prepare the object to sync to FLDigi.  Now let's "push" these changes:

fldigi.config()

Now things should change.  FLDigi should show the BPSK31 modem
selected, the carrier at 1000hz, AFC on, and squelch on and set to
3.0.  The radio should be tuned to 14.070mhz.

Now we can do a little housekeeping before we start sending and
receiving data.  We'll make sure we're in receive mode, and clear all
the buffers (sent and received) in FLDigi.  Note that these commands
execute immediately, without the need to "sync":

fldigi.receive()
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()

We're ready to rock and roll.  We can send data, receive data, etc.
Let's send a CQ.  There's two ways we can do this.  We could construct
a CQ string and send it to FLDigi, or tell the gem what our callsign
is and call the cq method.  We'll do the latter.  the cq() method puts
the CQ text into the object's output buffer, and send_buffer() sends
this buffer to FLDigi and initiates transmission:

fldigi.call="N0CLU"
fldigi.cq()
fldigi.send_buffer()

At this point, the radio should click over to transmit, and the CQ
call should be sent.  The radio will automatically switch back to
receive once the CQ is sent (the send_buffer() method watches FLDigi
until all buffered text has been transmitted).

That's it.  You can also send arbitrary text like this:

fldigi.add_tx_string("Now is the time for all good men to come to the aid of their country.")
fldigi.send_buffer()

You can see everything that has been received since the last time you
asked like this:

puts get_rx_data()

If you look at digitool.rb, there are working example of all of this
and more.

Jeff
N0GQ
