#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
# http://fldigi.gritch.org

# ToDo:
#
# - escape <<< and >>> from data field.
# - implement mutex-locked sequence numbers
# - sequence number should not be arbitrary and/or user-supplied

require 'zlib'
require 'base64'
require 'time'
require 'thread'
require 'fldigi'

HAMNET_FRAME_ACK=0
HAMNET_FRAME_SIMPLE=1
HAMNET_FRAME_BASE64=2
HAMNET_FRAME_COMPRESSED_BASE64=3
# To do.
HAMNET_FRAME_PING=4
HAMNET_FRAME_PING_REPLY=5
#HAMNET_FRAME_TELEMETRY=6
#HAMNET_FRAME_POSITION=7

# This defines a basic frame of data for use with fldigi.  The frame
# consists of:
#
# Header field.  Three bytes, consisting of "<<<"
# From field.  Nine bytes (allowing for "WA0AAA-0")
# To field.  Nine bytes (allowing for "WB0BBB-0")
# Type field.  Two bytes (two hex digits) specifying encoding, compression. If the high-order bit is set, this is the last frame of a sequence (ie, wait for the other side).
# Sequence field. Two bytes (two hex digits) specifying sequence number.
# Data field.  Arbitrary number of bytes of payload.
# CRC field.  Last eight bytes, CRC32 checksum of From, To, Type, Data fields.
# Trailer field.  Three bytes, consisting of ">>>"
class Frame
  attr_accessor :from, :to, :type, :sequence, :valid, :frompad, :topad, :done

  def initialize(from, to, type, sequence, done)
    @from=from.downcase
    @to=to.downcase
    @type=type
    @sequence=sequence
    @done=done
    @wiredata=nil
    @userdata=nil
    @crc=nil
    @valid=false

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
  attr_accessor :from, :to, :type, :sequence, :userdata, :wiredata, :done

  def initialize(from, to, type, sequence, userdata, done)
    # Create the object.
    super(from, to, type, sequence, done)
    @userdata=userdata

    sendtype=type
    if @done or @type==HAMNET_FRAME_ACK or @type==HAMNET_FRAME_PING or @type==HAMNET_FRAME_PING_REPLY
      sendtype=(sendtype|128)
    end

    # Do the needful with the payload.
    case @type
    when HAMNET_FRAME_PING
      message=@frompad+@topad+sprintf("%02x",sendtype).downcase+sprintf("%02x",@sequence).downcase
    when HAMNET_FRAME_PING_REPLY
      message=@frompad+@topad+sprintf("%02x",sendtype).downcase+sprintf("%02x",@sequence).downcase+@userdata
    when HAMNET_FRAME_ACK
      message=@frompad+@topad+sprintf("%02x",sendtype).downcase+sprintf("%02x",@sequence).downcase
    when HAMNET_FRAME_SIMPLE
      message=@frompad+@topad+sprintf("%02x",sendtype).downcase+sprintf("%02x",@sequence).downcase+@userdata
    when HAMNET_FRAME_BASE64
      message=@frompad+@topad+sprintf("%02x",sendtype).downcase+sprintf("%02x",@sequence).downcase+Base64::strict_encode64(@userdata)
    when HAMNET_FRAME_COMPRESSED_BASE64
      message=@frompad+@topad+sprintf("%02x",sendtype).downcase+sprintf("%02x",@sequence).downcase+Base64::strict_encode64(Zlib::Deflate.deflate(@userdata,Zlib::BEST_COMPRESSION))
    else
      return false
    end

    # Calculate the CRC.
    @crc=sprintf("%08x",Zlib::crc32(message)).downcase

    # Set the rest of the fields, and done.
    @wiredata="----------<<<#{message}#{@crc}>>>"
    @valid=true
  end
end

# This defines a frame received using fldigi.  You supply it with the
# frame (delimited with "<<<" and ">>>", and it validates the frame,
# then creates and populates an object with the fields of that frame.
class RxFrame < Frame
  attr_accessor :from, :to, :type, :sequence, :userdata, :wiredata, :done

  def initialize(wiredata)
    # First, make sure it's properly delimited.
    if wiredata=~/^<<<.*?>>>$/ and wiredata.length>=31
      begin
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
        # See if this is a "done" frame.
        done=false
        if type!=(type&127)
          done=true
          type=(type&127)
        end
        # Create and populate the object.
        super(from, to, type, sequence, done)
        @wiredata=wiredata
        # Decode the payload.
        case @type
        when HAMNET_FRAME_PING
          @userdata=""
        when HAMNET_FRAME_PING_REPLY
          @userdata=tmp
        when HAMNET_FRAME_ACK
          @userdata=""
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
      rescue
        # This is bad.
        return nil
      end
    else
      return nil
    end
  end
end

class Hamnet
  attr_accessor :mycall, :dialfreq, :carrier, :modem

  def initialize(mycall, dialfreq, carrier, modem)
    @mycall=mycall.downcase
    @dialfreq=dialfreq.to_f
    @carrier=carrier.to_i
    @modem=modem
    @sequence=0

    @queue_send=Array.new()
    @queue_recv=Array.new()
    @send_lock=Mutex.new()
    @recv_lock=Mutex.new()
    @seq_lock=Mutex.new()

    @fldigi=Fldigi.new()

    # May not need this. Seems to depend on ruby version.
    #if !XMLRPC::Config::ENABLE_NIL_PARSER
    #v, $VERBOSE=$VERBOSE, nil
    #XMLRPC::Config::ENABLE_NIL_PARSER=true
    #$VERBOSE=v
    #end

    # Light up FLDigi.
    @fldigi.receive()
    @fldigi.afc=false
    @fldigi.modem=@modem
    @fldigi.carrier=@carrier
    @fldigi.clear_tx_data()
    @fldigi.get_tx_data()
    @fldigi.get_rx_data()
    @fldigi.config()

    # Crank up the main thread.
    @loopthread=Thread.new { self.main_loop() }
    @loopthread.abort_on_exception=true
  end

  def main_loop
    rxdata=""
    frame=nil
    while true

      # First, send any queued outgoing frames.
      @send_lock.synchronize {
        while @queue_send.length>0 do
          f=@queue_send.shift
          puts "Transmit frame:\n#{f.to_s}"
          @fldigi.add_tx_string(f.to_s)
          @fldigi.send_buffer(true)
        end
      }

      # Get any new data from fldigi. Strip out any Unicode bullshit.
      rx=@fldigi.get_rx_data()
      rx.each_codepoint do |i|
        if i>=32 and i<=126
          rxdata=rxdata+i.chr
        end
      end

      if rxdata.length>1024
        l=rxdata.length
        rxdata=rxdata[80,l-1024]
      end

      if rxdata.scan(/</).length==0
        rxdata=""
      elsif rxdata.scan(/<<</).length>0
        rxdata=rxdata.match(/<<<.*/).to_s
      end

      # If there's a valid frame in there, process it.
      if rxdata.match(/<<<.*>>>/).to_s.length>0
        rawframe=rxdata.reverse.match(/>>>.*?<<</).to_s.reverse

        # Parse the recieved frame.
        if rawframe.length>0
          frame=RxFrame.new(rawframe)

          if frame.valid and frame.to==@mycall
            @recv_lock.synchronize {
              puts "Received valid frame with my call sign:"
              p frame
              @queue_recv.push(frame)
            }
          end

          # Remove the frame text from the buffer.
          rxdata.slice!(rawframe)
        end
      end

      # If there's a valid ping frame in the recv_queue, remove it and
      # generate a reply ping frame.
      @recv_lock.synchronize {
        if @queue_recv.length>0
          puts "length:  #{@queue_recv.length}"
          p @queue_recv
          tmp_queue=Array.new()
          @queue_recv.each do |tmpframe|
            if tmpframe.type==HAMNET_FRAME_PING
              self.send_frame(TxFrame.new(@mycall, tmpframe.from, HAMNET_FRAME_PING_REPLY, 0, @fldigi.radio_freq().to_s, true))
            elsif tmpframe.type==HAMNET_FRAME_PING_REPLY
              puts "Received a reply to our ping:"
              p tmpframe
            else
              tmp_queue.push(tmpframe)
            end
          end
          @queue_recv=tmp_queue
        end
      }

      sleep 1
    end
  end

  def send_frame(frame)
    len=nil
    @send_lock.synchronize {
      @seq_lock.synchronize {
        frame.sequence=@sequence
        @sequence=@sequence+1
        @queue_send.push(frame)
        puts "Frame added to queue_send:\n#{frame.to_s}"
        len=@queue_send.length
      }
    }
    return(len)
  end

  def recv_frame()
    frame=nil
    @recv_lock.synchronize {
      if @queue_recv.length>0
        frame=@queue_recv.shift
      end
    }
    return(frame)
  end

  def ping(hiscall)
    self.send_frame(TxFrame.new(@mycall, hiscall, HAMNET_FRAME_PING, 0, nil, true))
    return(nil)
  end
end
