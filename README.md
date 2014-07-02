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

```ruby
require 'fldigi'
```

Next, connect to fldigi.  There are three parameters that can be
supplied here.  The simplest is to supply no parameters, which makes
the assumption that fldigi is running on the default port on the same
host that this script is running on (ie, localhost/127.0.0.1), and
that you've configured both FLDigi and your radio for remote control
of frequency, mode, etc:

```ruby
fldigi=Fldigi.new()
```

If you have not wired and configured your radio for remote control, do
this, instead:

```ruby
fldigi=Fldigi.new(false)
```

You can also optionally supply an IP address and a port number if
you're trying to control FLDigi on another host or on a nonstandard
port.

The variable 'fldigi' is now your "handle" for talking to FLDigi.  Be
aware that FLDigi does some semi-illegal things with XMLRPC, including
sometimes returning 'nil' as a result.  This is not uncommon, but
technically not allowed by the standard.  So you have to tell ruby to
allow for this deviation:

```ruby
XMLRPC::Config::ENABLE_NIL_PARSER=true
```

Most parameters within the object default to something sane at the
time of creation, but there are a few things you might want to set.
Be aware that the fldigi gem works by keeping an internal state, then
"pushing" that state to the radio when requested.  Though some
commands trigger an immediate API call to FLDigi, most manipulate
internal object state, which does not affect the radio until you
"sync" them.  Let's set up some state (even though some of these are
already defaulted to the values we're setting):

Choose the PSK31 modem.
```ruby
fldigi.modem="BPSK31"
```

Use a carrier frequency of 1khz (the "sweet spot" in most radios).
```ruby
fldigi.carrier=1000
```

Set the dial frequency to 14.07mhz (final xmt freq is dial+carrier, or 14.071mhz).
```ruby
fldigi.dial_freq=14070000
```

Turn on squelch.
```ruby
fldigi.squelch=true
```

Set the squelch value to 3.0 (reasonable for most radios).
```ruby
fldigi.slevel=3.0
```

Turn on AFC.
```ruby
fldigi.afc=true
```

Note that at this point, nothing on the radio has actually changed
(nor has anything in the FLDigi program).  All we've done is to
prepare the object to sync to FLDigi.  Now let's "push" these changes:

```ruby
fldigi.config()
```

Now things should change.  FLDigi should show the BPSK31 modem
selected, the carrier at 1000hz, AFC on, and squelch on and set to
3.0.  The radio should be tuned to 14.070mhz.

Now we can do a little housekeeping before we start sending and
receiving data.  We'll make sure we're in receive mode, and clear all
the buffers (sent and received) in FLDigi.  Note that these commands
execute immediately, without the need to "sync":

```ruby
fldigi.receive()
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
```

We're ready to rock and roll.  We can send data, receive data, etc.
Let's send a CQ.  There's two ways we can do this.  We could construct
a CQ string and send it to FLDigi, or tell the gem what our callsign
is and call the cq method.  We'll do the latter.  the cq() method puts
the CQ text into the object's output buffer, and send_buffer() sends
this buffer to FLDigi and initiates transmission:

```ruby
fldigi.call="N0CLU"
fldigi.cq()
fldigi.send_buffer()
```

At this point, the radio should click over to transmit, and the CQ
call should be sent.  The radio will automatically switch back to
receive once the CQ is sent (the send_buffer() method watches FLDigi
until all buffered text has been transmitted).

That's it.  You can also send arbitrary text like this:

```ruby
fldigi.add_tx_string("Now is the time for all good men to come to the aid of their country.")
fldigi.send_buffer()
```

You can see everything that has been received since the last time you
asked like this:

```ruby
puts get_rx_data()
```

Here's a simple example to call CQ where you specify the dial
frequency and the desired carrier.  This example will transmit on
14071000hz:

```ruby
require 'fldigi'

  fldigi=Fldigi.new()
  fldigi.call="N0CLU"
  fldigi.carrier=1000
  fldigi.dial_freq=14070000
  fldigi.modem="BPSK31"
  if fldigi.config()
    fldigi.clear_tx_data()
    fldigi.get_tx_data()
    fldigi.cq()
    fldigi.send_buffer()
  end
```

Here's a different way to do the same thing.  This time, we specify
the desired transmit frequency, rather than specifying the dial
frequency (just set fldigi.carrier to the sweet spot in your audio
first).  This example also transmits on 14071000hz, it's just a
different way of doing the same thing:

```ruby
  require 'fldigi'

  fldigi=Fldigi.new()
  fldigi.call="N0CLU"
  fldigi.carrier=1000
  fldigi.freq(14071000)
  fldigi.modem="BPSK31"
  if fldigi.config()
    fldigi.clear_tx_data()
    fldigi.get_tx_data()
    fldigi.cq()
    fldigi.send_buffer()
  end
```

Here's a simple example to send a random bit of text:

```ruby
  require 'fldigi'

  fldigi=Fldigi.new()
  fldigi.dial_freq=18110000
  fldigi.carrier=1200
  fldigi.modem="BPSK63"
  if fldigi.config()
    fldigi.clear_tx_data()
    fldigi.get_tx_data()
    fldigi.add_tx_string("This is a random bit of text de N0CLU")
    fldigi.send_buffer()
  end
```

Here's a simple example to send a PropNet beacon (note that PropNet
functionality is untested):

```ruby
  require 'fldigi'

  fldigi=Fldigi.new()
  fldigi.call="N0CLU"
  fldigi.band=20
  fldigi.phg="PHG410015"
  fldigi.grid="CN87wu"
  fldigi.propnet()
  if fldigi.config()
    fldigi.clear_tx_data()
    fldigi.get_tx_data()
    while true
      fldigi.send_buffer()
      sleep fldigi.delay
    end
  end
```

If you look at digitool.rb and propnet.rb, there are working example
of all of this and more.  There is also some other random information
on the [fldigi-ruby home page](http://fldigi.gritch.org)

Jeff
N0GQ
