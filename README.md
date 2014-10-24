#fldigi-ruby

===========

## Description

fldigi-ruby is a ruby gem for interfacing with the FLDigi API.  The intent is to be able to use fldigi as a radio modem from ruby scripts (though it's useful for other tasks, as well, such as changing frequencies on a schedule, fetching the current radio frequency for insertion into a log, etc).

I love FLDigi.  One of my favorite features is the API.  But talking directly to the XML-RPC API is a bit of a pain in the ass from random ruby code, so I wrote a gem to abstract it a layer, and remove some of the "ick" factor.  The documenation for the FLDigi API is, to put it kindly, a little lacking.  It basically amounts to a one-line
description of each call (see
[here](http://www.w1hkj.com/FldigiHelp-3.22/xmlrpc-control.html)).

The best documentation has turned out to be reading the FLDigi source.

This gem makes all of this just a bit easier to use.  I've also included a couple of demonstration clients.  The first client allows you to send CQ from the command line, or to send any arbitrary text, using whatever frequency, carrier, mode, and modem you wish.  The second client is a PropNET client written in ruby that uses FLDigi as a modem.  Be aware that I haven't tested the propnet client yet, other than to verify that the output looks sane.  There are some potential issues with the checksum (ie, PropNet claims to use CRC16 in the documentation, but online discussion says it's a broken implementation of CRC16 - meaning mine may not be compatible, since mine may not be "properly broken").  The third client (not quite ready to publish) is an PSK31/PSK63 HF APRS client.

This code has been tested on Linux and OS/X, and so far, works perfectly.  I do not own or currently have access to a Windows box, so your mileage may vary there.  Please provide feedback for features and bugs.  My time is limited, but I'll do what I can.  My intent is that library calls won't change, only new calls will be added, but at this point, it's early enough in the development cycle that I can't promise that.  In fact I've already broken that promise at least once.  Turns out I didn't think through the freq() method well when I first started out.  Had to change it from a variable to a method, which would have broken any pre-existing code.  But it had to be done.  You can see what's changed from version to version by viewing the [NEWS](https://github.com/jfrancis42/fldigi-ruby/blob/master/NEWS) file.
    
There's a lot to be desired in things like validating and error-checking of user input.  For example, if you enter bogus fields for phg (for propnet), it'll either send bad data, or barf, depending on which value you hork up.  Input validation is on the very long list of To-Do items.

## First Things First

Before you can have any hope of using this library, you first need to make sure that FLDigi is installed and working correctly and that it's correctly talking to your radio.  If either of these aren't working, you have little to no chance of doing anything useful.

You should be able to have a PSK-31 conversation with FLDigi.  You should have your computer audio wired to your radio, and you should have all of your levels set right (ie, don't overdrive the transmit - if your ALC is moving, you've got it set too high).  If you can have a nice digital QSO with somebody with your setup in it's current condition, you're 1/3 of the way there.

Second step is to make sure that FLDigi can control the mode and frequency of your radio.  You should be able to change bands and frequencies by clicking on the FLDigi user interface.  Obviously, this requires some wiring between your computer and your radio.  With most radios, this is pretty simple.  I bought USB cables on EBay for about $20 each for my Icom and Yaesu radios that take care of this.  It's certainly possible to homebrew your own interfaces (I used to do it that way in Ye Olden Dayes of Yore).  If you can't control the dial frequency, you're stuck with manual tuning, and FLDigi only has about 3khz of spectrum to work with.  Which, in turn, means your code only has about 3khz to work with.  You can certainly still do some things, but you're severely crippling yourself.  If you're good here, that's 2/3 done.

Finally, you need to install the library.  I'm going to make the assumption you've already got ruby installed.  Which means you just need to add the fldigi gem.  On a Mac or Linux, open a terminal, and run:

```bash
sudo gem install fldigi
```

This will go fetch and install the latest version of the gem on your machine.  As the code is still under development, it might be worthwhile to update it regularly (I keep finding bugs and squashing them).  If you have Windows, you'll need to do whatever the equivalent function is to download and install the gem.  I've tested this pretty heavily on Mac and Linux, but I don't own a Windows machine, so I've never tested it in that environment.  I *should* work, but I honestly don't know.  Once you've got the libraries installed, you're 3/3 done with your preparations.

You will also need the Digest CRC gem (digest-crc) written by Hal Brodigan.  This gem is necessary for computing the CCITT CRC16 checksum used for propnet.  Install it like this:

```bash
sudo gem install digest-crc
```

## How to Use

To use the API, you'll first need to require it:

```ruby
require 'fldigi'
```

Next, connect to fldigi.  There are three parameters that can be supplied here.  The simplest is to supply no parameters, which makes the assumption that fldigi is running on the default port on the same host that this script is running on (ie, localhost/127.0.0.1), and that you've configured both FLDigi and your radio for remote control of frequency, mode, etc:

```ruby
fldigi=Fldigi.new()
```

If you have not wired and configured your radio for remote control, do this, instead:

```ruby
fldigi=Fldigi.new(false)
```

You can also optionally supply an IP address and a port number if you're trying to control FLDigi on another host or on a nonstandard port.

The variable 'fldigi' is now your "handle" for talking to FLDigi.  Be aware that FLDigi does some semi-illegal things with XMLRPC, including sometimes returning 'nil' as a result.  This is not uncommon, but technically not allowed by the standard.  So you have to tell ruby to allow for this deviation:

```ruby
XMLRPC::Config::ENABLE_NIL_PARSER=true
```

Most parameters within the object default to something sane at the time of creation, but there are a few things you might want to set.  Be aware that the fldigi gem works by keeping an internal state, then "pushing" that state to the radio when requested.  Though some commands trigger an immediate API call to FLDigi, most manipulate
internal object state, which does not affect the radio until you "sync" them.  Let's set up some state (even though some of these are already defaulted to the values we're setting):

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

Note that at this point, nothing on the radio has actually changed (nor has anything in the FLDigi program).  All we've done is to prepare the object to sync to FLDigi.  Now let's "push" these changes:

```ruby
fldigi.config()
```

Now things should change.  FLDigi should show the BPSK31 modem selected, the carrier at 1000hz, AFC on, and squelch on and set to 3.0.  The radio should be tuned to 14.070mhz.

Now we can do a little housekeeping before we start sending and receiving data.  We'll make sure we're in receive mode, and clear all the buffers (sent and received) in FLDigi.  Note that these commands execute immediately, without the need to "sync":

```ruby
fldigi.receive()
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
```

We're ready to rock and roll.  We can send data, receive data, etc. Let's send a CQ.  There's two ways we can do this.  We could construct a CQ string and send it to FLDigi, or tell the gem what our callsign is and call the cq method.  We'll do the latter.  the cq() method puts the CQ text into the object's output buffer, and send_buffer() sends
this buffer to FLDigi and initiates transmission:

```ruby
fldigi.call="N0CLU"
fldigi.cq()
fldigi.send_buffer()
```

At this point, the radio should click over to transmit, and the CQ call should be sent.  The radio will automatically switch back to receive once the CQ is sent (the send_buffer() method watches FLDigi until all buffered text has been transmitted).

That's it.  You can also send arbitrary text like this:

```ruby
fldigi.add_tx_string("Now is the time for all good men to come to the aid of their country de N0CLU")
fldigi.send_buffer()
```

You can see everything that has been received since the last time you asked like this:

```ruby
puts get_rx_data()
```

Here's a simple example to call CQ where you specify the dial frequency and the desired carrier.  This example will transmit on 14071000hz:

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

Here's a different way to do the same thing.  This time, we specify the desired transmit frequency, rather than specifying the dial frequency (just set fldigi.carrier to the sweet spot in your audio first).  This example also transmits on 14071000hz, it's just a
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

Here's a simple example to send a PropNet beacon (note that PropNet functionality is untested):

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

## Included Scripts

### digitool.rb

The digitool.rb script does a bunch of random (and hopefully useful) things.  It'll call CQ for you, it'll randomly tune around the band segment you're in, finding QSOs and printing them, and other assorted things.  Mostly, it serves as an example of how to use the fldigi library.  I tried to make the defaults reasonably sane.  For example, unless you specify otherwise (by using --carrier), the audio carrier defaults to 1000hz.  so if you say "./digitool.rb --txfreq 14071000", it'll set your dial frequency to 14070000hz and your carrier to 1000hz, so your transmit (and receive) frequency will be 14071000hz.  If you tell it "./digitool.rb --dialfreq 14070000", you'll get exactly the same transmit/receive frequency.  Hopefully, being able to specify the dial frequency, the transmit frequency, and/or the carrier frequency will clear up some of the problems that newcomers have to using digital modes.  I sometimes find it useful to do something like:

```
while [ 1 ]; do ./digitool.rb --call n0clu --cq --txfreq 14106500 --carrier 1500 --modem Olivia-32-1K --listen 60; done
```

This will transmit a CQ on 20M in Olivia 32/1000, listen for sixty seconds, then repeat forever.  If/when I get an answer to my CQ, I just ^C the script, and move over to FLDigi and continue the QSO.

### propnet.rb

Connects to a local FLDigi instance with the default API port and sends a PropNet beacon.  Has the option of continuing to do so at a specified interval forever.  Note (see above) that the PropNet client may or may not be working.  I've tried sending beacons with it, and they don't show up on the PropNet page.  That may be bad luck, or it may be broken.  Or more precisely, it may (or may not) need to have it's CRC16 calculation broken to match the (possibly) broken one used by PropNet.  I'm a little unclear on all of this, as some online discussion claims it's broken, and other discussion says it isn't.  At any rate, I couldn't get it to work as-is, though it does follow their documented format precisely.  Making it work is on my to-do list.  Example use:

```
./propnet.rb --call N0CLU --band 40 --phg PHG410015 --grid DM79wu
```

See [the PropNet web site](http://propnet.org) for more information, such as how to set --phg.

### listen.rb

listen.rb and talk.rb are a pair of programs I wrote out of sheer frustration.  I'm constantly wanting to test different propagation, antennas, modes, and power levels between two points, but finding someone to man the station at random odd hours to do the testing has not proven fruitful.  Not to mention, even if I could find a willing victim, it might be a different victim with different antennas, power levels, and equipment each time, so results from one test might not be comparable to results from a second test.  This pair of programs is the result of that frustration.  The idea is simple.  I run listen.rb on my home station.  Every sixty seconds, it changes to the next (out of five) frequency, and listens for sixty seconds for my call sign on the mode I've specified.  If it hears it, it sends me a text message on my phone with the frequency, signal quality, and timestamp.  Meanwhile, I pack up a second station and take it with me wherever I want to test from (camping, a business trip, a city park a few miles down the road, whatever).  I plug in the Signalink, the radio, and the GPS receiver, and then fire up talk.rb.  Assuming I have my clock set accurately on both stations (I used ntpd on the home station and a combination of ntpd and gpsd on the remote station), talk.rb starts sending out location data once per minute, on each of five bands.  Any time my home station hears my remote station, I get a text message that tells me how well it was heard.  Viola, problem solved with technology.  If I'm camping out of range of cell service, I simply read through the FLDigi logs when I return home and correllate the timestamps in the logs with the notes I made in the field (regarding power, antenna, etc).

So, specifics...  listen.rb requires several parameters.  It requires a call sign to listen for using `--call`, a list of five frequencies to step through (or you can use my default list using `--defaults`), a modem (it defaults to BPSK-31), and a method of sending you messages (currently configured for sending texts via Google Voice or PushOver (both free services).  Both Google Voice and PushOver require login credentials, so either or both service credentials must be specified in a YAML file that you specify with `--creds`.  It's a standard YAML file, and looks like this:

```
---
gvlogin: n0clu@gmail.com
gvpasswd: n0treallyap@ssw0rd
pouser: uJDjjd77djUUUdxllvyw8EN9qzzyP
potoken: kAidUen74nahDUYembdye886cjd73nd
```

`gvlogin` is your Google login, `gvpasswd` is your Google password, `pouser` is your PushOver UserID, and `potoken` is your PushOver API token.  You can put creds for both services in the same file if you wish, but it's only required to have one (either one) of them.

### talk.rb

talk.rb has essentially the same options as listen.rb, with a couple of exceptions.  First, it will require you to specify the number of iterations through the five frequencies you'd like to make.  It's not intended to run forever like a beacon, it's intended to run through the set two or three times (to make sure you've got at least two or three chances on each band), then you stop, change something (power, location, antenna, whatever), and try again.  Once it changes to a new band, you have ten seconds before transmissions start.  This is to give you a chance to listen for other activity on frequency that you might interfere with.  If somebody is on your exact frequency, hit "^C" and wait until they're done (or click the carrier over to an empty part of the band in FLDigi using your mouse).  You also either need to be running gpsd on your remote system, or specify your latitude, longitude, and altitude manually.  Latitude and longitude are specified as decimals (ie, 123.456789).  Latitude is positive in the Northern Hemisphere, negative in the Southern.  Longitude is negative in the Western Hemisphere, positive in the Eastern.  Altitude is in feet because I'm an American and because I'm a pilot (both of whom have standardized on the "wrong" system).  There are roughly 3.3ft in one meter.  As with listen.rb, you can optionally specify a list of five frequencies, or use my defaults.  The modem must match that used by listen.rb.

===========

If you look at digitool.rb and propnet.rb, there are working example of all of this and more.  There is also some other random information on the [fldigi-ruby home page](http://fldigi.gritch.org), though I'm slowly moving that information into this document.

===========

73
Jeff
N0GQ
