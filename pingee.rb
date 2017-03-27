#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# <<<n0gq-7   n0gq-9   8400f6cf893a>>>

require 'time'
require 'thread'
require 'zlib'
require 'base64'
require 'rubygems'
require 'trollop'
require 'fldigi'
require 'hamnet'

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do command line option parsing.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

opts=Trollop::options do
  opt :host, "The FLDigi host (defaults to localhost)", :type => :string
  opt :port, "The FLDigi port (defaults to 7362)", :type => :string
  opt :mycall, "My call sign", :type => :string
  opt :norigctl, "Use if FLDigi is not configured to remotely control your radio frequency"
  opt :dialfreq, "Dial frequency (hz, defaults to 14070000 same as --txfreq if combined with --carrier)", :type => :string
  opt :txfreq, "Transmit frequency (hz, defaults to 14071000, assuming default 1khz carrier, overrides --dialfreq)", :type => :string
  opt :offset, "Frequency offset of this rig relative to your standard (in hz)", :type => :string
  opt :carrier, "Audio center frequency (hz, defaults to 1000)", :type => :string
  opt :modem, "Modem (defaults to QPSK63)", :type => :string
  opt :modems, "List available FLDigi modems"
end

if !opts[:mycall_given]
  puts "--mycall is mandatory"
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
else
  fldigi.modem="QPSK63"
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do the needful.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Set all of the random things that need setting before we begin.
fldigi.receive()
fldigi.afc=false
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
fldigi.config()

rxdata=""
prevrx=""
frame=nil

while true

  # Get any new data from fldigi.
  rx=fldigi.get_rx_data()
  rx.each_codepoint do |i|
    if i>=32 and i<=126
      rxdata=rxdata+i.chr
    end
  end

  if rxdata.length>127
    rxdata=rxdata[80,rxdata.length-127]
  end

  puts rxdata if rxdata.length>0 and rxdata!=prevrx

  if rxdata.scan(/</).length==0
    rxdata=""
  elsif rxdata.scan(/<<</).length>0
    rxdata=rxdata.match(/<<<.*/).to_s
  end

  if rxdata.match(/<<<.*>>>/).to_s.length>0
    # If there's a valid frame in there, process it.
    tmp=rxdata.reverse.match(/>>>.*?<<</).to_s.reverse

    if tmp.length>0
      puts "We received a frame."
      
      # Parse the recieved frame.
      frame=RxFrame.new(tmp)
      p frame

      if frame.valid
        puts "Frame is valid."
        
        if frame.to==opts[:mycall]
          puts "Destination call matches mine."
          
          # Let the other guy finish (unless it's Olivia).
          if fldigi.modem.match(/^Olivia/).to_s.length==0
            puts "Waiting for transmitting station to finish..."
            sleep 10
          end
          
          # Now generate and send a reply.
          puts "Sending reply frame..."
          fldigi.add_tx_string(TxFrame.new(frame.to, frame.from, HAMNET_FRAME_PING_REPLY, 0, fldigi.radio_freq().to_s, true).to_s)
          fldigi.send_buffer(true)
          puts "Reply frame transmission complete."
        else
          puts "Destination call does not match mine."
        end

      else
        puts "Frame is not valid."
      end

      # Remove the frame text from the buffer.
      rxdata.slice!(tmp)

    end
  end

  sleep 1
  prevrx=rxdata
end
