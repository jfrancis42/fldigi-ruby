#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
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

require 'io/console'
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
  opt :debug, "Show extra debug info (not useful for most users)"
  opt :host, "The FLDigi host (defaults to localhost)", :type => :string
  opt :port, "The FLDigi port (defaults to 7362)", :type => :string
  opt :message, "The message to be sent", :type => :string
  opt :dialfreq, "Dial frequency (hz, defaults to 14070000 same as --txfreq if combined with --carrier)", :type => :string
  opt :txfreq, "Transmit frequency (hz, defaults to 14071000, assuming default 1khz carrier, overrides --dialfreq)", :type => :string
  opt :offset, "Frequency offset of this rig relative to your standard (in hz)", :type => :string
  opt :norigctl, "Use if FLDigi is not configured to remotely control your radio frequency"
  opt :carrier, "Audio center frequency (hz, defaults to 1000)", :type => :string
  opt :getfreq, "Get the current carrier frequency"
  opt :modem, "Modem (defaults to BPSK31)", :type => :string
  opt :afc, "Set AFC on or off (defaults to on)", :type => :string
  opt :squelch, "Set the squelch level (defaults to 3.0)", :type => :string
  opt :uuclient, "Use STDIO for send/recv as a uucico pipe"
  opt :listen, "Listen for n seconds incoming data (use 0 to listen forever)", :type => :string
  opt :wander, "Wander up and down the audio passband looking for signals"
  opt :common, "List common PSK31 dial frequencies"
  opt :modems, "List available FLDigi modems"
  opt :list, "List available FLDigi API commands"
end

# If the user asks, give him some common PSK31 dial frequencies.
if opts[:common_given]
  puts "Common dial frequencies (plus a carrier of roughly 500-2500hz):"
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

if opts[:afc_given]
  if opts[:afc]=="on" or opts[:afc]=="ON" or opts[:afc]=="On"
    fldigi.afc=true
  else
    fldigi.afc=false
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
fldigi.config()

# Either send a CQ, go into interactive mode, or send the message
# specified by the user.
 if opts[:uuclient_given]

  m=Mutex.new
  incoming=""
  incoming_old=nil
  last_time=0

  t=Thread.new do
    while true
      c=STDIN.getch
      if c=='q'
        exit
      end
      m.synchronize do
        incoming=incoming+c
      end
      last_time=Time.now.to_f
    end
  end
  t.abort_on_exception=true

  mode="rx"
  while true
    #puts "mode:  #{mode}\r"

    if Time.now.to_f-last_time < 2.0
      if mode!="tx"
        #puts "Switching to transmit...\r"
        mode="tx"
        fldigi.send_buffer(true)
      else
        m.synchronize do
          if incoming.length>0
            fldigi.add_tx_string(incoming)
            #puts "#{Time.now.to_f-last_time}: -->#{incoming}<--"
            incoming=""
          end
        end
      end
      
    else
      if mode!="rx"
        #puts "Switching to receive...\r"
        mode="rx"
        sleep 3
      end
    end

    sleep 1
  end

elsif opts[:cq_given] and opts[:call_given]
  fldigi.cq()
  fldigi.send_buffer(true)
elsif opts[:message_given]
  fldigi.add_tx_string(opts[:message])
  fldigi.send_buffer(true)
end

# When we're done with everything else, go into an infinite listen
# loop if requested.
now=Time.now().to_i
if opts[:listen_given]
  search=true
  while true
    q=fldigi.quality().to_i
    # If the signal quality is less than 25, search for a (new) signal
    # to watch.  Also, I have a birdies/carriers that shows up about
    # 14070105 and 14070135 that FLDigig mistakenly locks onto in
    # PSK31 mode all the time and just spews the letter 'e' endlessly.
    # If the carrier falls way down at the bottom of the waterfall on
    # 20M (where there are never useful signals, anyway), ignore it.
    if q<25 or (fldigi.freq()>14070000 and fldigi.freq()<14070140 and fldigi.modem=="BPSK31")
      if opts[:wander_given]
        if rand(2)==0
          fldigi.search_up()
        else
          fldigi.search_down()
        end
      end
    else
      puts "(#{q} #{fldigi.freq()} #{Time.now().to_s}) #{fldigi.get_rx_data().gsub(/(\n|\r)/,' ')}"
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
