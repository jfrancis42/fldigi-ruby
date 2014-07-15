#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
# http://fldigi.gritch.org

require 'zlib'
require 'base64'
require 'time'
require 'thread'

FRAME_SIMPLE=0
FRAME_BASE64=1
FRAME_COMPRESSED_BASE64=2
# To do.
FRAME_PING=3
FRAME_PING_REPLY=4
FRAME_TELEMETRY=5
FRAME_POSITION=6

# This defines a basic frame of data for use with fldigi.  The frame
# consists of:
#
# Header field.  Three bytes, consisting of "<<<"
# From field.  Eight bytes (allowing for "WA0AAA-0")
# To field.  Eight bytes (allowing for "WB0BBB-0")
# Type field.  One byte (numeric) specifying encoding, compression.
# Data field.  Arbitrary number of bytes of payload.
# CRC field.  Last eight bytes, CRC32 checksum of From, To, Type, Data fields.
# Trailer field.  Three bytes, consisting of ">>>"
class Frame
  attr_accessor :from, :to, :type, :valid, :frompad, :topad

  def initialize(from, to, type)
    @from=from.downcase
    @to=to.downcase
    @type=type
    @wiredata=nil
    @userdata=nil
    @crc=nil
    @valid=nil

    @frompad=@from
    while @frompad.length<8
      @frompad=@frompad+":"
    end

    @topad=@to
    while @topad.length<8
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
  attr_accessor :from, :to, :type, :userdata, :wiredata

  def initialize(from, to, type, userdata)
    # Create the object.
    super(from, to, type)
    @userdata=userdata

    # Do the needful with the payload.
    case @type
    when FRAME_SIMPLE
      message=@frompad+@topad+@type.to_s+@userdata
      @crc=Zlib::crc32(message).to_s(16).downcase
      while @crc.length<8
        @crc="0"+@crc
      end
    when FRAME_BASE64
      message=@frompad+@topad+@type.to_s+Base64::strict_encode64(@userdata)
      @crc=Zlib::crc32(message).to_s(16).downcase
      while @crc.length<8
        @crc="0"+@crc
      end
    when FRAME_COMPRESSED_BASE64
      message=@frompad+@topad+@type.to_s+Base64::strict_encode64(Zlib::Deflate.deflate(@userdata,Zlib::BEST_COMPRESSION))
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
  attr_accessor :from, :to, :type, :userdata, :wiredata

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
      from=tmp[0,8].gsub(":","")
      tmp=tmp[8,tmp.length-8]
      # Extract and clean the to field.
      to=tmp[0,8].gsub(":","")
      tmp=tmp[8,tmp.length-8]
      # Extract the frame type.
      type=tmp[0,1].to_i
      tmp=tmp[1,tmp.length-1]
      # Create and populate the object.
      super(from, to, type)
      @wiredata=wiredata
      # Decode the payload.
      case @type
      when FRAME_SIMPLE
        @userdata=tmp
      when FRAME_BASE64
        @userdata=Base64::strict_decode64(tmp)
      when FRAME_COMPRESSED_BASE64
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
