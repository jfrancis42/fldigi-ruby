#fldigi-ruby

===========



##Description

fldigi-ruby is a ruby gem for interfacing with the FLDigi API.  The
intent is to be able to use fldigi as a radio modem from ruby scripts
(though it's useful for other tasks, as well, such as changing
frequencies on a schedule, fetching the current radio frequency, etc).

I love FLDigi.  One of my favorite features is the API.  But talking
directly to the XML-RPC API is a bit of a pain in the ass from random
ruby code, so I wrote a gem to abstract it a layer, and remove some of
the "ick" factor.  The documenation for the FLDigi API is, to put it
kindly, a little lacking.  It basically amounts to a one-line
description of each call (see
[here](http://www.w1hkj.com/FldigiHelp-3.22/xmlrpc-control.html)).
The best documenation has turned out to be reading the FLDigi source.

At any rate, I've written a gem to make all of this just a bit easier
to use.  I've also written a few demonstration clients.  The first
client allows you to send CQ from the command line, or to send any
arbitrary text, using whatever frequency, carrier, mode, and modem you
wish.  The second client is a PropNET client written in ruby that uses
FLDigi as a modem.  Be aware that I haven't tested the propnet client
yet, other than to verify that the output looks sane.  The third
client (not quite ready to publish) is an PSK31/PSK63 APRS client.  At
this point, there is no documentation save this page and the demo
code.

This code has been tested on Linux and OS/X, and so far, works
perfectly.  I do not own or currently have access to a Windows box, so
your mileage may vary there.  Please provide feedback for features and
bugs.  My time is limited, but I'll do what I can.  My intent is that
library calls won't change, only new calls will be added, but at this
point, it's early enough in the development cycle that I can't promise
that.
    
There's a lot to be desired in things like validating and
error-checking of user input.  For example, if you enter bogus fields
for phg (for propnet), it'll either send bad data, or barf, depending
on which value you hork up.  Input validation is on the very long list
of To-Do items.


##How to Use

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

Set the dial frequency to 14.070mhz (final xmt freq is dial+carrier, or 14.071mhz).

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
fldigi.add_tx_string("Now is the time for all good men to come to the aid of their country de N0CLU")
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

##Included Scripts

###digitool.rb

The digitool.rb script does a bunch of random (and hopefully
useful) things.  It'll call CQ for you, it'll randomly tune
around the band segment you're in, finding QSOs and printing
them, and other assorted things.  Mostly, it serves as an
example of how to use the fldigi library.  I tried to make the
defaults reasonably sane.  For example, unless you specify
otherwise (by using --carrier), the audio carrier defaults to
1000hz.  so if you say "./digitool.rb --txfreq 14071000", it'll
set your dial frequency to 14070000hz and your carrier to
1000hz, so your transmit (and receive) frequency will be
14071000hz.  If you tell it "./digitool.rb --dialfreq
14070000", you'll get exactly the same transmit/receive
frequency.  Hopefully, being able to specify the dial
frequency, the transmit frequency, and/or the carrier frequency
will clear up some of the problems that newcomers have to using
digital modes.  I sometimes find it useful to do something like:

```
while [ 1 ]; do ./digitool.rb --call n0gq --cq --txfreq 14106500 --carrier 1500 --modem Olivia-32-1K --listen 60; done
```

This will transmit a CQ on 20M in Olivia 32/1000, listen for
sixty seconds, then repeat forever.  If/when I get an answer, I
just ^C the script, and move over to FLDigi for the QSO.

###propnet.rb

Connects to a local FLDigi instance with the default API port.  Example use:

```
./propnet.rb --call N0CLU --band 40 --phg PHG410015 --grid DM79wu
```

See [the PropNet web site](http://propnet.org) for more information, such as how to set --phg.


If you look at digitool.rb and propnet.rb, there are working example
of all of this and more.  There is also some other random information
on the [fldigi-ruby home page](http://fldigi.gritch.org)

Jeff
N0GQ
