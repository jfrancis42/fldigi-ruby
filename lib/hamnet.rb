#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
# http://fldigi.gritch.org

# ToDo:
#
# Escape <<< >>> from data field.

require 'zlib'
require 'base64'
require 'time'
require 'thread'

HAMNET_FRAME_ACK=0
HAMNET_FRAME_SIMPLE=1
HAMNET_FRAME_BASE64=2
HAMNET_FRAME_COMPRESSED_BASE64=3
# To do.
HAMNET_FRAME_PING=4
HAMNET_FRAME_PING_REPLY=5
HAMNET_FRAME_TELEMETRY=6
HAMNET_FRAME_POSITION=7

# This defines a basic frame of data for use with fldigi.  The frame
# consists of:
#
# Header field.  Three bytes, consisting of "<<<"
# From field.  Nine bytes (allowing for "WA0AAA-0")
# To field.  Nine bytes (allowing for "WB0BBB-0")
# Type field.  Two bytes (two hex digits) specifying encoding, compression.
# Sequence field. Two bytes (two hex digits) specifying sequence number.
# Data field.  Arbitrary number of bytes of payload.
# CRC field.  Last eight bytes, CRC32 checksum of From, To, Type, Data fields.
# Trailer field.  Three bytes, consisting of ">>>"
class Frame
  attr_accessor :from, :to, :type, :sequence, :valid, :frompad, :topad

  def initialize(from, to, type, sequence)
    @from=from.downcase
    @to=to.downcase
    @type=type
    @sequence=sequence
    @wiredata=nil
    @userdata=nil
    @crc=nil
    @valid=nil

    @frompad=@from
    while @frompad.length<9
      @frompad=@frompad+":"
    end

    @topad=@to
    while @topad.length<9
      @topad=@topad+":"
    end
  end

  def to_s
    return @wiredata
  end
end

# This defines a frame to be transmitted using fldigi.  You need to
# supply the originating call sign (from), the destination call sign
# (to), the type of frame (see constants above), and the actual data
# to be transmitted.
class TxFrame < Frame
  attr_accessor :from, :to, :type, :sequence, :userdata, :wiredata

  def initialize(from, to, type, sequence, userdata)
    # Create the object.
    super(from, to, type, sequence)
    @userdata=userdata

    # Do the needful with the payload.
    case @type
    when HAMNET_FRAME_SIMPLE
      message=@frompad+@topad+sprintf("%02x",@type).upcase+sprintf("%02x",@sequence).upcase+@userdata
      @crc=Zlib::crc32(message).to_s(16).downcase
      while @crc.length<8
        @crc="0"+@crc
      end
    when HAMNET_FRAME_BASE64
      message=@frompad+@topad+sprintf("%02x",@type).upcase+sprintf("%02x",@sequence).upcase+Base64::strict_encode64(@userdata)
      @crc=Zlib::crc32(message).to_s(16).downcase
      while @crc.length<8
        @crc="0"+@crc
      end
    when HAMNET_FRAME_COMPRESSED_BASE64
      message=@frompad+@topad+sprintf("%02x",@type).upcase+sprintf("%02x",@sequence).upcase+Base64::strict_encode64(Zlib::Deflate.deflate(@userdata,Zlib::BEST_COMPRESSION))
      @crc=Zlib::crc32(message).to_s(16).downcase
      while @crc.length<8
        @crc="0"+@crc
      end
    else
      return false
    end

    # Set the rest of the fields, and done.
    @wiredata="<<<#{message}#{@crc}>>>"
    @valid=true
  end
end

# This defines a frame received using fldigi.  You supply it with the
# frame (delimited with "<<<" and ">>>", and it validates the frame,
# then creates and populates an object with the fields of that frame.
class RxFrame < Frame
  attr_accessor :from, :to, :type, :sequence, :userdata, :wiredata

  def initialize(wiredata)
    # First, make sure it's properly delimited.
    if wiredata=~/^<<<.*>>>$/ and wiredata.length>=31
      # Remove the "<<<" and ">>>"
      tmp=wiredata[3,wiredata.length-6]
      # Extract the crc field.
      crc=tmp[tmp.length-8,8]
      tmp=tmp[0,tmp.length-8]
      # Save this for checking CRC later.
      crcstring=tmp
      # Extract and clean the from field.
      from=tmp[0,9].gsub(":","")
      tmp=tmp[9,tmp.length-9]
      # Extract and clean the to field.
      to=tmp[0,9].gsub(":","")
      tmp=tmp[9,tmp.length-9]
      # Extract the frame type.
      type=tmp[0,2].to_i(16)
      tmp=tmp[2,tmp.length-2]
      # Extract the sequence number.
      sequence=tmp[0,2].to_i(16)
      tmp=tmp[2,tmp.length-2]
      # Create and populate the object.
      super(from, to, type, sequence)
      @wiredata=wiredata
      # Decode the payload.
      case @type
      when HAMNET_FRAME_SIMPLE
        @userdata=tmp
      when HAMNET_FRAME_BASE64
        @userdata=Base64::strict_decode64(tmp)
      when HAMNET_FRAME_COMPRESSED_BASE64
        @userdata=Zlib::Inflate.inflate(Base64::strict_decode64(tmp))
      end
      # Calculate and check the CRC.
      @crc=Zlib::crc32(crcstring).to_s(16).downcase
      if crc==@crc
        @valid=true
      end
    else
      return false
    end
  end
end
