#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
#
# v.0.1.0, 02.Jul.2014
#
# Connects to a local FLDigi instance with the default API port.  Example use:
#
# ./propnet.rb --call N0CLU --band 40 --phg PHG410015 --grid DM79wu
#
# See http://propnet.org for information, such as how to set --phg.

require "xmlrpc/client"
require 'zlib'
require 'base64'
require 'time'
require 'rubygems'
require 'trollop'
require 'fldigi'

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do command line option parsing.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

opts=Trollop::options do
  opt :call, "Call sign", :type => :string
  opt :host, "The FLDigi host (defaults to localhost)", :type => :string
  opt :port, "The FLDigi port (defaults to 7362)", :type => :string
  opt :psk63, "Use PSK63 (defaults to PSK31)"
  opt :band, "Band to beacon in (80, 40, 20, 17, 15, 12, 10, 6)", :type => :string
  opt :grid, "Grid square for use in PropNet (6 characters)", :type => :string
  opt :phg, "PHG for PropNet (format PHG410015 - beacons/hour will be extracted from this)", :type => :string
end

fldigi=Fldigi.new()

if !XMLRPC::Config::ENABLE_NIL_PARSER
  XMLRPC::Config::ENABLE_NIL_PARSER=true
end

if opts[:psk63_given]
  fldigi.modem="BPSK63"
else
  fldigi.modem="BPSK31"
end

if opts[:call_given]
  fldigi.call=opts[:call].downcase
else
  puts "Must specify --call"
  exit
end

if opts[:band_given]
  fldigi.band=opts[:band]
else
  puts "Must specify --band"
  exit
end

delay=nil
if opts[:phg_given]
  if opts[:phg][0,3]!="PHG"
    puts "--phg must begin with the letters PHG"
    exit
  else
    fldigi.phg=opts[:phg]
  end
else
  puts "Must specify --phg"
  exit
end

if opts[:band_given]
else
  puts "Must specify --band"
  exit
end

grid=nil
if opts[:grid_given]
  fldigi.grid=opts[:grid]
  if opts[:grid].length!=6
    puts "--pgrid must be six characters"
    exit
  end
else
  puts "Must specify --grid"
  exit
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Do the needful.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Set all of the random things that need setting.
fldigi.receive
fldigi.clear_tx_data()
fldigi.get_tx_data()
fldigi.get_rx_data()
fldigi.propnet_config()
fldigi.config()

if fldigi.delay
  while true
    fldigi.propnet()
    fldigi.send_buffer()
    sleep fldigi.delay
  end
else
  fldigi.propnet()
  fldigi.send_buffer()
end
