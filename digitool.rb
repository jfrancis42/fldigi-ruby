#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
# http://fldigi.gritch.org
#
# Send messages using FLDigi as a modem.  Talks to FLDigi via the
# built-in XML-RPC API (make sure you enable API access inside of
# FLDigi).  For the moment, this code only talks to an instance of
# FLDigi on the local machine using the default port (though the
# library fully supports remote hosts).  The only gem used that's not
# a native bit of ruby (besides 'fldigi', of course) is 'trollop'.
# Tested on Linux and OS/X.  I don't own a Windows machine to test
# with, but I see no reason it shouldn't work.  But if it doesn't,
# you'll have to fix it yourself.
#
# Assuming you have FLDigi set up and working correctly (ie, API is
# enabled and radio frequency control is wired up and configured),
# operation is as simple as:
#
# ./digi.rb --call N0CLU --cq
# ./digi.rb --freq 14097000 --carrier 1500 --message "Yo, dude, de N0CLU"
#
# Then go to the following web page and see if your call shows up
# after five minutes or so:
#
# http://pskreporter.info/pskmap.html

require 'time'
require 'thread'
require 'rubygems'
require 'trollop'
require 'fldigi'

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do command line option parsing.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

opts=Trollop::options do
  opt :call, "Call sign", :type => :string
  opt :cq, "Call CQ (must specify --call)"
  opt :host, "The FLDigi host (defaults to localhost)", :type => :string
  opt :port, "The FLDigi port (defaults to 7362)", :type => :string
  opt :message, "The message to be sent", :type => :string
  opt :dialfreq, "Dial frequency (hz, defaults to 14070000)", :type => :string
  opt :txfreq, "Transmit frequency (hz, defaults to 14071000, assuming default 1khz carrier, overrides --dialfreq)", :type => :string
  opt :offset, "Frequency offset of this rig relative to your standard (in hz)", :type => :string
  opt :norigctl, "Use if FLDigi is not configured to remotely control your radio frequency"
  opt :carrier, "Audio center frequency (hz, defaults to 1000)", :type => :string
  opt :getfreq, "Get the current carrier frequency"
  opt :modem, "Modem (defaults to BPSK31)", :type => :string
  opt :afc, "Set AFC on or off (defaults to on)", :type => :string
  opt :squelch, "Set the squelch level (defaults to 3.0)", :type => :string
  opt :listen, "Listen for n seconds incoming data (use 0 to listen forever)", :type => :string
  opt :quality, "Minimum quality level to lock onto a signal (0-100, defaults to 25)", :type => :string
  opt :wander, "Wander up and down the audio passband looking for signals"
  opt :common, "List common PSK31 dial frequencies"
  opt :modems, "List available FLDigi modems"
  opt :list, "List available FLDigi API commands"
  opt :file, "Write output to a file", :type => :string
  opt :filetimestamp, "Write output to a file named for current date/time"
  opt :debug, "Show extra debug info (not useful for most users)"
end

# If the user asks, give him some common PSK31 dial frequencies.
if opts[:common_given]
  puts "Common dial frequencies (plus a carrier of typically 500-2500hz):"
  puts "3580000, 7080000, 10142000, 14070000, 18100000, 21070000, 24920000, 28120000, 50290000"
  exit
end

if opts[:host_given]
  host=opts[:host]
end

if opts[:port_given]
  port=opts[:port].to_i
end

# Not everybody has rig control.
if opts[:norigctl_given]
  fldigi=Fldigi.new(false)
else
  fldigi=Fldigi.new()
end

# Turn on debug if they want it.
if opts[:debug_given]
  fldigi.debug=true
end

# See if the user wants to write output to a file.
fname=nil
file=nil
if opts[:file_given]
  fname=opts[:file]
end

# See if the user wants auto file naming.
if opts[:filetimestamp_given]
  fname="fldigi_" + Time.now().to_s.gsub(/ /,"_") + ".log"
end

# May not need this. Seems to depend on ruby version.
if !XMLRPC::Config::ENABLE_NIL_PARSER
  v, $VERBOSE=$VERBOSE, nil
  XMLRPC::Config::ENABLE_NIL_PARSER=true
  $VERBOSE=v
end

# Give the user a list of supported modems that can be specified with
# the '--modem' parameter.
if opts[:modems_given]
  puts fldigi.list_modems()
  exit
end

# Set the minimum interesting signal quality.
if opts[:quality_given]
  qual=opts[:quality].to_i
else
  qual=25
end

# Give the user a list of possible API calls (very few users will have
# a use for this).
if opts[:list_given]
  puts fldigi.list_api()
  exit
end

if opts[:squelch_given]
  if opts[:squelch].to_f==0.0
    fldigi.squelch=false
  else
    fldigi.squelch=true
    fldigi.slevel=opts[:squelch].to_f
  end
end

if opts[:carrier_given]
  fldigi.carrier=opts[:carrier].to_i
end

if opts[:dialfreq_given]
  fldigi.dial_freq=opts[:dialfreq].to_f
end

if opts[:txfreq_given]
  fldigi.freq(opts[:txfreq].to_i)
end

if opts[:offset_given]
  fldigi.offset=opts[:offset].to_f
end

if opts[:modem_given]
  fldigi.modem=opts[:modem]
end

if opts[:call_given]
  fldigi.call=opts[:call].upcase
end

if opts[:afc_given]
  if opts[:afc]=="on" or opts[:afc]=="ON" or opts[:afc]=="On"
    fldigi.afc=true
  else
    fldigi.afc=false
  end
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do the needful.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

if opts[:getfreq_given]
  puts fldigi.radio_freq()
  exit
end

# Set all of the random things that need setting.
fldigi.receive()
fldigi.spot=true
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
flag=false
if !fldigi.config()
  while fldigi.errors.length>0
    error=fldigi.errors.pop.to_s
    puts error
    if error=~/main\.set_frequency/
      flag=true
    end
  end
  if flag
    puts "Setup failed. You may need to specify --norigctl"
  else
    puts "Setup failed."
  end
  exit
end

# Either send a CQ or send the message specified by the user.
if opts[:cq_given] and opts[:call_given]
  fldigi.cq()
  fldigi.send_buffer(true)
elsif opts[:message_given]
  fldigi.add_tx_string(opts[:message])
  fldigi.send_buffer(true)
end

# If the user wants to log output to a file, open that file.
if fname
  file=File.open(fname,'w')
  file.sync=true
end

# When we're done transmitting, go into an infinite listen loop (if
# requested).
now=Time.now().to_i
if opts[:listen_given]
  search=true
  while true
    q=fldigi.quality().to_i
    # If the signal quality is less than 25, search for a (new) signal
    # to watch. 50/50 chance of searching up or down (assuming the NSA
    # hasn't tinkered with your random number generator).
    if q<qual
      if opts[:wander_given]
        if rand(2)==0
          fldigi.search_up()
        else
          fldigi.search_down()
        end
      end
    else
      rxdata=fldigi.get_rx_data().gsub(/(\n|\r)/,' ')
      puts "(#{q} #{fldigi.radio_freq()} #{Time.now().to_s}) #{rxdata}"
      if fname
        file.puts "(#{q} #{fldigi.radio_freq()} #{Time.now().to_s}) #{rxdata}"
      end
    end

    # Listen for however long was specified (or forever if zero).
    if opts[:listen].to_i>0
      if Time.now().to_i>now+opts[:listen].to_i
        exit
      end
    end

    sleep 3
  end
end

# Close the output file (assuming it was open).
if fname
  file.close()
end
