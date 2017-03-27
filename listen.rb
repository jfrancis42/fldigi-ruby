#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
#
# See http://fldigi.gritch.org for documentation.

require 'io/console'
require 'time'
require 'yaml'
require 'rubygems'
require 'trollop'
require 'fldigi'

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do command line option parsing.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

opts=Trollop::options do
  opt :debug, "Show extra debug info (not useful for most users)"
  opt :host, "The FLDigi host (defaults to localhost)", :type => :string
  opt :port, "The FLDigi port (defaults to 7362)", :type => :string
  opt :call, "The call sign to watch for", :type => :string
  opt :modem, "Modem (defaults to BPSK31)", :type => :string
  opt :modems, "List available FLDigi modems"
  opt :creds, "YAML file containing Google Voice/PushOver credentials", :type => :string
  opt :gvoice, "Send a text to this number using Google Voice upon call match", :type => :string
  opt :pushover, "Send a message via PushOver upon call match"
  opt :defaults, "Use default freqs of 3581000, 7081000, 10143000, 14071000, 28121000"
  opt :freq1, "First frequency to listen on", :type => :string
  opt :freq2, "Second frequency to listen on", :type => :string
  opt :freq3, "Third frequency to listen on", :type => :string
  opt :freq4, "Fourth frequency to listen on", :type => :string
  opt :freq5, "Fifth frequency to listen on", :type => :string
end

if !opts[:defaults_given]
  if !opts[:freq1_given] or !opts[:freq2_given] or !opts[:freq3_given] or !opts[:freq4_given] or !opts[:freq5_given]
    puts "Must specify either --defaults or all five RX frequencies (duplicates are allowed)"
    exit
  else
    freq1=opts[:freq1].to_i
    freq2=opts[:freq2].to_i
    freq3=opts[:freq3].to_i
    freq4=opts[:freq4].to_i
    freq5=opts[:freq5].to_i
  end
end

if opts[:creds_given]
  creds=YAML.load(File.read(opts[:creds]))
  
  if opts[:gvoice_given] and creds.has_key?("gvlogin") and creds.has_key?("gvpasswd")
    require 'googlevoiceapi'
    gvapi=GoogleVoice::Api.new(creds['gvlogin'],creds['gvpasswd'])
  end
  
  if opts[:pushover_given] and creds.has_key?("pouser") and creds.has_key?("potoken")
    require 'pushover'
  end  
else
  puts "Invalid notification method (either you forgot --gvoice or --pushover, or your --creds are broken)."
  exit
end

if opts[:host_given]
  host=opts[:host]
end

if opts[:port_given]
  port=opts[:port].to_i
end

if opts[:call_given]
  call=opts[:call].downcase
else
  puts "--call is required"
  exit
end

# Talk to the mother ship.
fldigi=Fldigi.new()

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

if opts[:modem_given]
  fldigi.modem=opts[:modem]
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do the needful.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Set all of the random things that need setting.
fldigi.receive
fldigi.spot=true
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
fldigi.config()

# Go into an infinite listen loop.
if opts[:defaults_given]
  f=[3581000, 7081000, 10143000, 14071000, 28121000]
else
  f=[freq1, freq2, freq3, freq4, freq5]
end
search=true
last_freq=0
while true
  # Set the rx freq based on the time.
  t=Time.now()
  m=t.to_s.split[1].split(':')[1][1].to_i
  if m>4
    m=m-5
  end

  if last_freq!=f[m]
    last_freq=f[m]
    fldigi.freq(f[m])
    fldigi.carrier=1000
    fldigi.config()
    puts "#{t.to_s} #{fldigi.freq()}hz"
  end

  quality=fldigi.quality().to_i
  if quality<25
    if rand(2)==0
      fldigi.search_up()
    else
      fldigi.search_down()
    end
  else
    tmp="(#{quality} #{fldigi.freq()}hz #{Time.now().to_s}) #{fldigi.get_rx_data()}"
    puts tmp
    if tmp.downcase.match(call)
      if opts[:gvoice_given]
        gvapi.sms(opts[:gvoice],tmp)
      end

      if opts[:pushover_given]
        Pushover.notification(message: ARGV[0], title: opts[:call],
                              user: creds['pouser'] , token: creds['potoken'])
      end
    end
  end
  sleep 3
end
