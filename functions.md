# FLDigi Ruby Gem

***

# THIS DOCUMENT IS INCOMPLETE, AND IS A WORK IN PROGRESS

***

The philosophy of the fldigi gem is that there is an internal data structure that contains the desired state at any given time, and that this data structure is either synced *to* fldigi and the radio, or synced *from* fldigi and the radio on demand.  In normal usage, any number of parameters in the data structure can be manipulated, then all changes are pushed as a batch at the desired time.  This minimizes the amount of time the radio might spend in an "awkward" or partially-configured state (though the time is not zero, as commands to the radio are still sent serially, and may take as much as several hundred milliseconds to sync, depending on the changes made).  By necessity, there are other commands that are executed immediately.  The majority of these are lower-level functions used by the library itself, but they are exposed for use for cases where they might be of value.  An example of these is `fldigi.receive()`.  This function immediately tells FLDigi to go into receive mode, which in turn immediately tells the radio to do the same.  While this isn't something that's used often in user-level programs, it might be prudent to ensure the radio is in receive mode before performing certain actions (like changing frequencies or modem types).

There are two text buffers to be aware of.  First, there is a text buffer in FLDigi.  In normal keyboard use, this buffer holds the text to be sent.  You type what you like in the buffer, then click the "Send" button, and that text is sent.  This same buffer is used by the API.  When you send text to FLDigi via the API, the text is held in the FLDigi buffer until you instruct FLDigi to send it.  The second buffer to be aware of is in the fldigi ruby object.  Text is added to that buffer as desired, then "pushed" to FLDigi, where it then resides in FLDigi's buffer until FLDigi is instructed to send it.  When you're playing with the gem, be aware of which buffer you're manipulating.  Some of the gem calls manage all of this for you (they push text to the object's buffer, push that buffer to FLDigi, then send the data).  Other API calls do some subset of this.  An example is `fldigi.cq()`.  When you call the cq function, it places a CQ message in the object's outgoing buffer, but does not send it.  You must then call `fldigi.send_buffer()` to actually send this text.  The send_buffer() function takes care of pushing the object's buffer to FLDigi, switching the radio to transmit, and waiting until the entire buffer is sent, then returning.  This is the most commonly used way of sending data.

In typical use, the fldigi object is first created, and various desired parameters are set in the object itself, then that object is "synced" with FLDigi and the radio.  The object is created in typical ruby fashion:  `fldigi=Fldigi.new()`.  Various parameters can be passed, as documented below.  The object is created with some reasonably sane defaults, such as BPSK-31 mode, a radio dial frequency of 14.070mhz, a carrier of 1000hz, AFC on, squelch on, and a squelch level of 3.0.  Any of these parameters (and more) can be set before syncing to the radio.  Parameters are set by either setting a variable within the object, or calling the appropriate object method (these are documented below).  An example would be turning AFC off:  `fldigi.afc=false`.  Once all variables, modes, etc. are set to desired values, call `fldigi.config()` to actually transfer these setting to FLDigi and the radio.  Unless a function is documented as having an immediate effect, you must call this function before any change you make has an effect on FLDigi or the radio.  The first time config() is called, it will set all possible parameters.  Since pushing parameters is not fast, subsequent calls will only push a subset of the data.  Frequency and carrier will always be pushed (since the user may have futzed with the radio dial and/or moved the audio carrier with his mouse of AFC).  Other parameters will only be pushed if they have been changed since the last time config() was called.

***

### Variables Available to Applications

***

### host

```ruby
host=host
```

Reading this variable will tell you the DNS name or IP address of the
host that's running FLDigi that we're talking to.  Setting this
variable will have no effect.

### port

```ruby
port=port
```

Reading this variable will tell you the port number on the host that's
running FLDigi that we're talking to.  Setting this variable will have
no effect.

### rigctl

```ruby
rigctl=rigctl
```

Reading this variable will tell you whether or not fldigi thinks it
has frequency control over the radio.  Possible values are
true/false.  Setting this variable once the object is initialized has
undefined behavior (ie, don't do it).

### dial_freq

```ruby
dial_freq=14070000.0
```

Setting this variable (and then calling `fldigi.config()`) will cause
the radio to tune to this dial frequency.  Defaults to 14.070mhz.
Reading this variable will show you what dial frequency the radio was
last told to tune to.  Note that this may be different than the actual
radio dial frequency if the user has played with the radio.

### carrier

```ruby
carrier=1000
```

Setting this variable (and then calling `fldigi.config()`) will cause
the carrier to be set to this frequency.  Defaults to 1000hz.  Reading
this variable will show you what the carrier was last set to, which
may be different than the actual current carrier due to AFC and/or the
user clicking in the waterfall window on FLDigi.

### call

```ruby
call=nil
```

This variable contains a string representing your call sign.  This
variable defaults to an empty string.  This value must be set prior to
calling the `fldigi.cq()` function or the `fldigi.propnet_config()`
function.

### modem

```ruby
modem="BPSK31"
```

Setting this variable (and then calling `fldigi.config()`) will cause
the FLDigi modem to be set to this type.  Reading this value will
return the value that the FLDigi modem type was last set to.  This may
not represent the current modem setting, as the user may have changed
it using the FLDigi UI.  This value defaults to "BPSK31".  Valid
values may be obtained by either calling `fldigi.list_modems()`, or by
manually setting the desired modem type using the FLDigi GUI and using
the value in the bottom left corner of the FLDigi GUI interface.

### afc

```ruby
afc=true
```

Setting this variable (and then calling `fldigi.config()`) will cause
AFC to be turned on or off (valid values true/false).  Reading this
value will return the value that the AFC was last set to.  This may
vary from reality due to the user clicking the AFC button in the
FLDigi GUI.

### rsid

```ruby
rsid=nil
```

blah blah blah...

### sideband

```ruby
sideband="USB"
```

blah blah blah...

### squelch

```ruby
squelch=true
```

Setting this variable (and then calling `fldigi.config()`) will cause
squelch to be turned on or off (valid values true/false).  Note that
some modems do not have squelch.  Reading this value will return the
value that the squelch was last set to.  This may vary from reality
due to the user clicking the Squelch button in the FLDigi GUI.

### slevel

```ruby
slevel=3.0
```

Setting this variable (and then calling `fldigi.config()`) will cause
the squelch value to be set in FLDigi (note that some modems do not
have squelch).  Reading this value will return the value that the
squelch was last set to.  This may vary from reality due to the user
dragging the squelch slider up and down in the FLDigi GUI.

### spot

```ruby
spot=nil
```

Setting this variable (and then calling `fldigi.config()`) will cause
Spot to be turned on or off (valid values true/false).  Reading this
value will return the value that the Spot was last set to.  This may
vary from reality due to the user clicking the Spot button in the
FLDigi GUI.

### offset

```ruby
offset=0
```

This variable represents the offset of the transmitter's frequency from perfect.  In most cases, it's perfectly safe to ignore this and leave it at the default of 0.  In the case where you're trying to connect to another transceiver on a specific frequency with a very narrow modem such as BPSK31, it might be necessary to set this variable.  As an example, my FT-817 and IC-706MkII are 182hz off from each other.  While this is a small amount for voice communications, it's far enough apart that two BPSK31 signals would never connect.  In cases like this, it's not really relevant or important what's used as a frequency standard.  Either radio can be the standard by which the other is calibrated.  If one of the radios is out of your control, it's necessary to use an external standard.  Perhaps WWV.  This value can be positive or negative.

### start_wait

```ruby
start_wait=10
```

When data is submitted for transmission, the library watches for characters to be echoed back one at a time as they are sent.  When transmission is complete, the sending function returns.  This variable represents the number of seconds that the library waits for the first character to be sent before returning failure.  For many modems with a fast set-up, this value can be set fairly low.  Other modems, particularly when RSID is sent for each transmission, this number needs to be higher.  The number is automatically set by the library for some common modems, but has not been tested exhaustively.

### char_wait

```ruby
char_wait=2
```

This variable, like `start_wait` has to do with sending characters.  This value represents how long the library waits for the next character before returning failure.  The default of two seconds was chosen as an outer limit.  This number can be lower for many modems.  This number also represents how long the library waits after sending the last character of a transmission before switching the radio back to receive, so setting it too high results in a long idle "hang time" after all data is sent.

### band

```ruby
band=nil
```

This variable is used by the `fldigi.propnet()` function to determine which band to tune the radio to before sending the PropNet transmission.  The value is an integer, such as 6, 10, 12, 15, 17, 20, 30, 40, 80, or 160.  The frequency within the band is pre-determined and set by the library.

### fsym

```ruby
fsym=nil
```

Each PropNet band has a pre-determined alpha-numeric code.  This variable represents the code for the band chosen.  Setting this variable yourself will probably break something.

### delay

```ruby
delay=nil
```

This variable represents the number of seconds to wait between PropNet transmissions.  It is set automatically by setting PHG (see below).  Do not set manually.

### grid

```ruby
grid=nil
```

This number represents the six-digit grid square used for your PropNet transmission.

### phg

```ruby
phg=nil
```

This is a string representing the PHG value to be sent by PropNet.  PHG is documented on the [PropNet Home Page](http://propnet.org).  Per the standard, this string *must* being with the characters "PHG".

### phgtext

```ruby
phgtext=""
```

This is the internally constructed string that is sent as the PHG transmission.  Don't touch.

***

## Setup and Initialization

***

### initialize()
```ruby
def initialize(rigctl=true, host="127.0.0.1", port=7362)
```

This function is the actual object creation method that is called upon initial creation of the fldigi object:  `fldigi=Fldigi.new()`

This function will never be directly called by the end user, other than for initial object creation.  There are three possible arguments, all of which are optional.  Default behavior is to assume that FLDigi has been configured for rig control, that it is running on the same machine that this API call is being made from, and that it is running on the default port (7362).  If your radio is not frequency controlled by FLDigi, provide the argument `false` when creating the object.  If the instance of FLDigi is running on another host, you must supply all three arguments (rig control, host name/IP, and port number).  Most users will create the object with no options.

### sendcmd()
```ruby
def sendcmd(cmd, param=-1)
```

Send an XML-RPC command to FLDigi.  This function will rarely (if ever) be called by application-level software.  It is used extensively by the library itself, but is unlikely to be necessary to and end user.  It is provided in the off chance that it may be useful.  If you don't know exactly what you're doing, ignore this call.

### config()
```ruby
def config
```

Push all of the changed settings to FLDigi.  Anything that has not
changed is not pushed (to save time).

***

## Controlling the Radio

***

### receive()
```ruby
def receive
```

Set FLDigi to receive (immediate).

### transmit()
```ruby
def transmit
```

Set FLDigi to transmit (immediate).  When switched to transmit, FLDigi
will send whatever text exists in FLDigi's transmit buffer (which is
*not* the same thing as this object's internal message queue called
@message).

### freq()
```ruby
def freq(f=false)
```

Get/set the transmit frequency (dial frequency plus carrier).  If you
don't supply a parameter, this method returns the transmit frequency
you most recently specified.  IMPORTANT: The returned value may not be
where the radio is currently tuned.  This function returns what you
*told* the radio to be, which could be different than what it's
currently set to.  It's entirely possible that the user turned the
knob after you set the frequency.  If you want to see what the radio
is *actually* tuned to, use the radio_freq() method (below).  This
method does, however, go out and read the actual current carrier, as
that tends to float around due to both the user clicking on the
waterfall, and naturally due to AFC.  If you do supply a parameter, it
sets the transmit frequency by subtracting the currently requested
carrier (ie, not the actual current carrier, but what you set @carrier
to) from the supplied frequency, then setting @dial_freq to that
value.  For example, if @carrier was set to 1000 and you called
self.freq(14071000), @dial_freq would be set to 14070000.  Note that
this only sets up all the values in the object, you still have to
"push" them to the radio with the self.config() method.

### radio_freq()

```ruby
def radio_freq
```

Read the real freq plus real carrier from the radio (contrast with
freq() above).

### search_up()

```ruby
def search_up
```

Search upwards for a signal (immediate).

### search_down()
```ruby
def search_down
```

Search downwards for a signal (immediate).

### get_carrier()
```ruby
def get_carrier
```

Get current carrier (use this when you want to know what the carrier
actually *is* right at this moment, as opposed to what you last set it
to (it can drift if AFC is on, or the user clicks the waterfall)).

***

## Sending/Receiving Data

***

### send_buffer()
```ruby
def send_buffer(verbose=false)
```

Send the currently buffered data using the carrier, mode, frequency,
etc. currently configured.  The current code will wait up to
@start_wait (10) seconds for the first character to be transmitted
(this gives time for really slow modems to get rolling).  Once the
first sent character is detected, it makes sure it sees as least one
character every @char_wait (2) seconds (which again, is just enough
for the very slowest modem).  You can set the @char_wait value lower
if you're only going to use fast modems, but if you forget and use a
slow modem with this set lower, you'll chop off your own transmissions
before completion.  This value also affects how long of an idle is
left after the last character before switching back to receive.
Everything's a trade-off...  If you keep adding data to the buffer
(ie, calling add_tx_string()) while transmitting, it'll keep sending
data until the buffer is empty.  If you set verbose to true,
send_buffer() will display a running stream of transmitted data to
STDOUT.

### add_tx_string()
```ruby
def add_tx_string(text)
```

Add a string of text to the outgoing buffer.  If you want carriage
returns, you must supply them as part of the text (ie, "foo\n").  This
text is not sent until you call send_buffer(), unless send_buffer() is
already running.

### quality()
```ruby
def quality
```

Return the modem signal quality in the range [0:100] (immediate).

### get_rx_data()
```ruby
def get_rx_data
```

Return the received data accumulated since the last time you asked.

### get_tx_data()
```ruby
def get_tx_data
```

Return the tranmitted data accumulated since the last time you asked.

### clear_rx_data()
```ruby
def clear_rx_data
```

Clear FLDigi's incoming data buffer (you probably don't want to do
this, except *possibly* the first time you connect).

### clear_tx_data()
```ruby
def clear_tx_data
```

Clear any buffered untransmitted data (as with clear_rx_data(), this
is something you'll use sparingly, if ever).

### clear_message()
```ruby
def clear_message
```

Clear out the internal buffered message.  This clears the internal
object's message queue, but does not change what may or may not be
queued in FLDigi for transmission (clear_tx_data() does that).

***

## CQ

***

### cq()
```ruby
def cq
```

Queues up a CQ call.  Requires that @call be previously set, else
returns false.  Call send_buffer() after to begin transmission.

***

## PropNet

***

### propnet_config()
```ruby
def propnet_config
```

Setup for propnet.  You must call config() one time after this before
propnet() can be called as many times as desired.  If @band, @grid,
@phg, or @call changes between calls to propnet(), this method (and
config()) must be called again.

### propnet()
```ruby
def propnet
```

Queue the pre-built PropNET packet (must call propnet_config() and
 config() first).  Requires @grid, @call, @band, and @phg to be set.
 Call send_buffer() after to start the actual transmission.

### crc16(buf, crc=0)()
```ruby
def crc16(buf, crc=0)
```

CRC16 function for use with propnet.  "Borrowed" from:
http://www.hadermann.be/blog/32/ruby-crc16-implementation/

***

## Misc

***

### list_modems()
```ruby
def list_modems
```

Return a list of valid modems supported by FLDigi.  Note that not all
modems make sense and/or will work.  Like Feld Hell, for example.  Or
the Wefax modes.  And not all modes are 8-bit-clean.

### list_api()
```ruby
def list_api
```

Return a list of supported API calls (this is mostly for development).

