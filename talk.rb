#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
#
# See http://fldigi.gritch.org for documentation.

require 'io/console'
require 'time'
require 'json'
require 'thread'
require 'rubygems'
require 'trollop'
require 'fldigi'

$my_lat=0
$my_lon=0
$my_alt=0
$my_last=0
$my_new=false
$gpsd_lock=false

def gpsd(host, port)
  s=TCPSocket.open(host, port)
  s.puts '?WATCH={"enable":true,"json":true}'

  while true
    s.puts '?POLL;'
    
    line=s.gets
    now=Time.now
    updated=false
    thing=JSON.parse(line)

    tmp_lat=thing['lat'].to_f
    tmp_lon=thing['lon'].to_f
    tmp_alt=thing['alt'].to_f
    
    if tmp_lat!=0
      $my_lat=tmp_lat
      updated=true
    end

    if tmp_lon!=0
      $my_lon=tmp_lon
      updated=true
    end

    if tmp_alt!=0
      $my_alt=(tmp_alt*3.281).to_i
      updated=true
    end

    if updated==true
      $my_last=now
      $my_new=true
    end

    if tmp_lat+tmp_lon+tmp_alt!=0.0 and !$gpsd_lock
      $gpsd_lock=true
    end

    sleep 1
  end
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do command line option parsing.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

opts=Trollop::options do
  opt :debug, "Show extra debug info (not useful for most users)"
  opt :host, "The FLDigi host (defaults to localhost)", :type => :string
  opt :port, "The FLDigi port (defaults to 7362)", :type => :string
  opt :modem, "Modem (defaults to BPSK31)", :type => :string
  opt :modems, "List available FLDigi modems"
  opt :call, "The call sign to watch for", :type => :string
  opt :iterations, "How many transmit iterations through all five frequencies", :type => :string
  opt :defaults, "Use default freqs of 3581000, 7081000, 10143000, 14071000, 28121000"
  opt :freq1, "First frequency to listen on", :type => :string
  opt :freq2, "Second frequency to listen on", :type => :string
  opt :freq3, "Third frequency to listen on", :type => :string
  opt :freq4, "Fourth frequency to listen on", :type => :string
  opt :freq5, "Fifth frequency to listen on", :type => :string
  opt :gpsd, "Use gpsd for location"
  opt :gpsdhost, "Specify gpsd host (defaults to localhost)", :type => :string
  opt :gpsdport, "Specify gpsd port (defaults to 2947)", :type => :string
  opt :lat, "Manually specify latitude (dd.ddddd)", :type => :string
  opt :lon, "Manually specify longitude (dd.ddddd)", :type => :string
  opt :alt, "Manually specify altitude (feet)", :type => :string
end

if opts[:iterations_given]
  iterations=opts[:iterations].to_i*5
else
  iterations=5
end

if opts[:gpsd_given]
  if opts[:gpsdhost_given]
    gpsd_host=opts[:gpsdhost]
  else
    gpsd_host="127.0.0.1"
  end

  if opts[:gpsdport_given]
    gpsd_port=opts[:gpsdport].to_i
  else
    gpsd_host=2947
  end
else
  if !opts[:lat_given] or !opts[:lon_given] or !opts[:alt_given]
    puts "Must specify location manually if not using --gpsd"
    exit
  end

  manual_lat=opts[:lat].to_f
  manual_lon=opts[:lon].to_f
  manual_alt=opts[:alt].to_i
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

if opts[:call_given]
  call=opts[:call].downcase
else
  puts "--call is required"
  exit
end

if opts[:host_given]
  host=opts[:host]
end

if opts[:port_given]
  port=opts[:port].to_i
end

if opts[:modems_given]
  puts fldigi.list_modems()
  exit
end

if opts[:modem_given]
  fldigi.modem=opts[:modem]
end

if opts[:gpsd_given]
  # Talk to gpsd.
  gps=Thread.new { gpsd(gpsd_host, gpsd_port) }
  gps.abort_on_exception=true

  while !$gpsd_lock
    puts "Waiting for GPS lock..."
    sleep 1
  end
  puts "GPS lock achieved."
end

# Talk to the mother ship.
fldigi=Fldigi.new()

# May not need this. Seems to depend on ruby version.
if !XMLRPC::Config::ENABLE_NIL_PARSER
  v, $VERBOSE=$VERBOSE, nil
  XMLRPC::Config::ENABLE_NIL_PARSER=true
  $VERBOSE=v
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do the needful.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Set all of the random things that need setting.
fldigi.receive
fldigi.spot=false
fldigi.carrier=1000
fldigi.afc=false
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
fldigi.config()

# Go into an infinite talk loop.
if opts[:defaults_given]
  f=[3581000, 7081000, 10143000, 14071000, 28121000]
else
  f=[freq1, freq2, freq3, freq4, freq5]
end
search=true
count=0
while count < iterations
  # Set the tx freq based on the time.
  t=Time.now()
  m=t.to_s.split[1].split(':')[1][1].to_i
  s=t.to_s.split[1].split(':')[2].to_i
  if s>=0 and s<=1
    if m>4
      m=m-5
    end

    fldigi.freq(f[m])
    fldigi.config()

  elsif s>=10 and s<=15

    # Send a location string on the new band.
    lat=$my_lat.to_s
    lon=$my_long.to_s
    alt=$my_alt.to_s

    puts "#{t.to_s} #{fldigi.freq()}hz #{$my_lat} #{$my_lon} #{$my_alt}ft"

    if opts[:gpsd_given]
      fldigi.add_tx_string("test location test location test location #{$my_lat}:#{$my_lon}:#{$my_alt}ft de #{opts[:call]} #{opts[:call]} #{opts[:call]}")
    else
      fldigi.add_tx_string("test location test location test location #{manual_lat}:#{manual_lon}:#{manual_alt}ft de #{opts[:call]} #{opts[:call]} #{opts[:call]}")
    end
    fldigi.send_buffer(false)
    count=count+1
  else
    sleep 1
  end
end
