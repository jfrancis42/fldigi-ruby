#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# Jeff Francis, N0GQ, jeff@gritch.org
# http://fldigi.gritch.org
#
# The FLDigi API is only very lightly documented (basically one
# sentence of explanation per API call), and there is essentially zero
# client source on the Internet to use as a reference (ie, to steal
# from) beyond what's shipped with FLDigi, so this code is a result of
# doing a lot of reading of the FLDigi source combined with trial and
# error.  What little documentation I can find is here:
#
# http://www.w1hkj.com/FldigiHelp-3.22/xmlrpc-control.html
#
# More documentation for this code is forthcoming, but for the moment,
# refer to the clients published on my web page to see how to use it.
#
# Note that the FLDigi API requires the following to work correctly:
#
# XMLRPC::Config::ENABLE_NIL_PARSER=true

require 'time'
require 'xmlrpc/client'
require 'thread'
require 'digest/crc16_ccitt'

# Turn 1/0 into false/true (some XMLRPC libraries seem to return 1/0,
# others true/false).  This cleans up the code a bit.
def torf(n)
  if n==0 or n==false
    return false
  else
    return true
  end
end

# Hold the error message generated (along with a timestamp).
class Error
  attr_accessor :timestamp, :text

  def initialize(text)
    @timestamp=Time.now()
    @text=text
  end

  def to_s
    "#{@timestamp.to_s}:  #{@text}"
  end
end

class Fldigi
  attr_accessor :rigctl, :dial_freq, :carrier, :call, :modem, :afc, :rsid, :sideband, :squelch, :slevel, :spot, :delay, :grid, :phg, :band, :offset, :start_wait, :char_wait, :debug, :errors, :fexpire

  # Do the initial setup.  All arguments are optional, default is
  # rigctl, localhost, standard port.  If you have no rig control,
  # call with Fldigi.new(false) (ie, it assumes you do have rig
  # control).  If you want to remote control an FLDigi instance that's
  # not on the local machine and/or has a non-standard port number,
  # you'll have to supply all three options, like
  # Fldigi.new(true,10.1.2.3,7362).
  def initialize(rigctl=true, host="127.0.0.1", port=7362)
    # Housekeeping.
    @host=host
    @port=port
    @message=""
    @rigctl=rigctl
    @errors=Array.new

    # Set up the defaults.
    @dial_freq=14070000.0
    @dial_freq_old=nil
    @carrier=1000
    @call=nil
    @call_old=nil
    @modem="BPSK31"
    @modem_old=nil
    @afc=true
    @afc_old=nil
    @rsid=nil
    @rsid_old=nil
    @sideband="USB"
    @sideband_old=nil
    @squelch=true
    @squelch_old=nil
    @slevel=3.0
    @slevel_old=nil
    @spot=nil
    @spot_old=nil
    @offset=0
    @offset_old=0
    @start_wait=10
    @char_wait=2
    @debug=false
    @fexpire=3
    @ftime=0

    # Propnet stuff.
    @band=nil
    @fsym=nil
    @delay=nil
    @grid=nil
    @phg=nil
    @phgtext=""

    # Connect to the FLDigi instance.
    @srvr=XMLRPC::Client.new(host,"/RPC2",port)
    @m=Mutex.new
  end

  # Add an error message to the queue.
  def error(text)
    @errors.push(Error.new(text))
  end

  # Send an XML-RPC command to FLDigi.
  def sendcmd(cmd, param=-1)
    if param==-1
      puts "sendcmd(#{cmd})" if @debug
      n=@srvr.call(cmd)
      puts "result: #{n}" if @debug
      return n
    else
      puts "sendcmd(#{cmd} #{param})" if @debug
      n=@srvr.call(cmd,param)
      puts "result: #{n}" if @debug
      return n
    end
  end

  # Push all of the changed settings to FLDigi.  Anything that has not
  # changed is not pushed (to save time).
  def config

    status=true

    # Set the audio carrier, but only if it's not false (so other
    # items can be updated without worrying about a little bit of
    # drift due to AFC).
    if @carrier
      @carrier=@carrier.to_i
      if @carrier!=self.get_carrier().to_i
        self.sendcmd("modem.set_carrier", @carrier)
      end
    end
    
    # Set the modem.  Also, take a stab at setting the timeouts for
    # that modem.  ToDo: Add to these as additional modems are checked
    # out, and save the user some hassle.
    if @modem!=@modem_old
      case @modem
      when "BPSK31"
        @start_wait=5
        @char_wait=1
      when "BPSK63"
        @start_wait=5
        @char_wait=0.5
      when "BPSK125"
        @start_wait=5
        @char_wait=0.5
      when "BPSK250"
        @start_wait=5
        @char_wait=0.5
      else
        @start_wait=10
        @char_wait=2
      end

      if @modem==self.sendcmd("modem.get_name")
        @modem_old=@modem
      else
        self.sendcmd("modem.set_by_name", @modem)
        if @modem==self.sendcmd("modem.get_name")
          @modem_old=@modem
        else
          self.error("modem.set_name failed with value #{@modem}")
          puts "modem.set_name failed" if @debug
          status=false
        end
      end
    end
    
    # Turn spot on/off (true/false).
    if @spot!=@spot_old
      if torf(self.sendcmd("spot.get_auto"))==@spot
        @spot_old=@spot
      else
        self.sendcmd("spot.set_auto", @spot)
      if torf(self.sendcmd("spot.get_auto"))==@spot
          @spot_old=@spot
        else
          self.error("spot.set_auto failed with value #{@spot}")
          puts "spot.set_auto failed" if @debug
          status=false
        end
      end
    end

    # Turn AFC on/off (true/false). Some modes don't work with
    # AFC. There seems to be a great deal of inconsistency (a bug,
    # maybe?) in reading the AFC value back from FLDigi. Every test I
    # can come up with points to a bug in their code, not mine. Until
    # we can get this sorted out, don't consider failure to set AFC as
    # fatal. Just unset it, and continue on. ToDo: Verify bug in
    # FLDigi, then fix.
    if (@afc!=@afc_old)
      if torf(self.sendcmd("main.get_afc"))==@afc
        @afc_old=@afc
      else
        self.sendcmd("main.set_afc", @afc)
        sleep 0.25
        if torf(self.sendcmd("main.get_afc"))==@afc
          @afc_old=@afc
        else
          @afc=false
          puts "main.set_afc failed, so leaving turned off" if @debug
        end
      end
    end

    # Set the sideband ("USB"/"LSB").  ToDo: make sure this is
    # correct.
    if @sideband!=@sideband_old
      if @sideband==self.sendcmd("main.get_sideband")
        @sideband_old=@sideband
      else
        self.sendcmd("main.set_sideband", @sideband)
        if @sideband==self.sendcmd("main.get_sideband")
          @sideband_old=@sideband
        else
          self.error("main.set_sideband failed with value #{@sideband}")
          puts "main.set_sideband failed" if @debug
          status=false
        end
      end
    end

    # Turn RSID receive on/off (true/false).
    if @rsid!=@rsid_old
      if torf(self.sendcmd("main.get_rsid"))==@rsid
        @rsid_old=@rsid
      else
        self.sendcmd("main.set_rsid", @rsid)
        if torf(self.sendcmd("main.get_rsid"))==@rsid
          @rsid_old=@rsid
        else
          self.error("main.set_rsid failed with value #{@rsid}")
          puts "main.set_rsid failed" if @debug
          status=false
        end
      end
    end
    
    # Turn squelch on/off (true/false).
    if @squelch!=@squelch_old
      if torf(self.sendcmd("main.get_squelch"))==@squelch
        @squelch_old=@squelch
      else
        self.sendcmd("main.set_squelch", @squelch)
        if torf(self.sendcmd("main.get_squelch"))==@squelch
          @squelch_old=@squelch
        else
          self.error("main.set_squelch failed with value #{@squelch}")
          puts "main.set_squelch failed" if @debug
          status=false
        end
      end
    end
    
    # Set the squelch value (3.0 seems to work well).
    if @slevel!=@slevel_old
      @slevel_old=@slevel
      if @slevel.to_f==self.sendcmd("main.get_squelch_level").to_f
        @slevel=@slevel.to_f
      else
        self.sendcmd("main.set_squelch_level", @slevel)
        if @slevel==self.sendcmd("main.get_squelch_level")
          @slevel=@slevel.to_f
        else
          self.error("main.set_squelch_level failed with value #{@slevel}")
          puts "main.set_squelch_level failed" if @debug
          status=false
        end
      end
    end

    # Set the radio frequency (in hz).  If the user has specified no
    # rig control, it simply returns true and ignores the provided
    # value (this is so people who don't have rig control can still
    # use the other features of the library, they just can't set the
    # radio frequency).  Otherwise, it returns true if successful in
    # setting the frequency, false if it fails.  The sleep here gives
    # the radio time to change frequencies before checking.  0.5
    # seconds work with all of my radios, but it's possible this will
    # need to be tweaked.  Send me an e-mail if this value is not
    # adequate for your radio, and I'll figure out a plan.  So far, it
    # works on my IC-706MkII, my IC-756Pro, and my FT-817.  The value
    # for @offset is added to the desired frequency.  This is for use
    # when you want all of your radios to be on a very specific given
    # frequency.  You must choose one as "the standard", then figure
    # out the offset for each rig from that standard.  For example, my
    # FT-817 transmits 180hz lower (for a given equal temperature).
    # Assuming I've chosen my IC-706MkII as my standard (of course,
    # you could use WWV or some such, as well), I need to set @offset
    # to -180 whenever using my FT-817 if I want them to be on the
    # exact same frequency.  This value could be added to either the
    # dial frequency or the carrier.  I chose the dial frequency,
    # since a lot of people reference the carrier more often than the
    # dial.  That way, when one person says he's at "1000", it'll be
    # "1000" on the other radio, as well.  There's no good, clean,
    # all-purpose solution to this one, but at least it allows for
    # consistent and automated use of the library without having to do
    # the conversions in your own code. We give ourselves two tries to
    # get the freq right, since some rigs seem to act a bit odd when
    # changing bands.
    @dial_freq=@dial_freq.to_i
    if (@dial_freq!=@dial_freq_old or @offset!=@offset_old) and @rigctl
      @dial_freq_old=@dial_freq
      @offset_old=@offset
      if @dial_freq+@offset.to_i!=self.sendcmd("main.get_frequency").to_f
        self.sendcmd("main.set_frequency", @dial_freq+@offset.to_f)
        sleep 0.5
        if @dial_freq+@offset.to_i!=self.sendcmd("main.get_frequency").to_f
          self.sendcmd("main.set_frequency", @dial_freq+@offset.to_f)
          sleep 0.5
          if @dial_freq+@offset.to_i!=self.sendcmd("main.get_frequency").to_f
            self.error("main.set_frequency failed with value #{@dial_freq}")
            puts "main.set_frequency failed" if @debug
            status=false
          end
        end
      end
    end

    return status
  end  

  # Set FLDigi to receive (immediate).
  def receive
    if self.sendcmd("main.get_trx_status")=="rx"
      return true
    else
      self.sendcmd("main.rx")
    end
    if self.sendcmd("main.get_trx_status")=="rx"
      return true
    else
      return false
    end
  end
  
  # Set FLDigi to transmit (immediate).  When switched to transmit,
  # FLDigi will send whatever text exists in FLDigi's transmit buffer
  # (which is *not* the same thing as this object's internal message
  # queue called @message).
  def transmit
    if self.sendcmd("main.get_trx_status")=="tx"
      return true
    else
      self.sendcmd("main.tx")
    end
    if self.sendcmd("main.get_trx_status")=="tx"
      return true
    else
      self.error("main.tx failed")
      return false
    end
  end
  
  # Get/set the transmit frequency (dial frequency plus carrier).  If
  # you don't supply a parameter, this method returns the transmit
  # frequency you most recently specified.  IMPORTANT: The returned
  # value may not be where the radio is currently tuned.  This
  # function returns what you *told* the radio to be, which could be
  # different than what it's currently set to.  It updates itself
  # every @fexpire seconds (3 by default), but it's entirely possible
  # that the user turned the knob in the three seconds since the last
  # time you set/checked the frequency.  If you want to see what the
  # radio is *actually* tuned to in real time, use the radio_freq()
  # method (below).  This method does, however, go out and read the
  # actual current carrier, as that tends to float around due to both
  # the user clicking on the waterfall, and naturally due to AFC.  If
  # you do supply a parameter, it sets the transmit frequency by
  # subtracting the currently requested carrier (ie, not the actual
  # current carrier, but what you set @carrier to) from the supplied
  # frequency, then setting @dial_freq to that value.  For example, if
  # @carrier was set to 1000 and you called self.freq(14071000),
  # @dial_freq would be set to 14070000.  Note that this only sets up
  # all the values in the object, you still have to "push" them to the
  # radio with the self.config() method.
  def freq(f=false)
    if f
      @dial_freq=f-@carrier
    else
      # If the last time we checked the dial frequency is more than
      # @fexpire seconds ago, re-read the frequency and update the
      # timestamp.
      if Time.now().to_i-@ftime>@fexpire
        @dial_freq=(self.radio_freq()+self.get_carrier()).to_i
        @ftime=Time.now().to_i
      end
      return (@dial_freq+self.get_carrier()).to_i
    end
  end

  # Read the real freq plus real carrier from the radio (contrast with
  # freq() above).
  def radio_freq
    return (self.sendcmd("main.get_frequency").to_i+self.get_carrier()).to_i
  end

  # Send the currently buffered data using the carrier, mode,
  # frequency, etc. currently configured.  The current code will wait
  # up to @start_wait seconds for the first character to be
  # transmitted (this gives time for really slow modems to get
  # rolling).  Once the first sent character is detected, it makes
  # sure it sees as least one character every @char_wait (2) seconds
  # (which again, is just enough for the very slowest modem).  You can
  # set the @char_wait value lower if you're only going to use fast
  # modems, but if you forget and use a slow modem with this set
  # lower, you'll chop off your own transmissions before completion.
  # This value also affects how long of an idle is left after the last
  # character before switching back to receive.  Everything's a
  # trade-off...  If you keep adding data to the buffer (ie, calling
  # add_tx_string()) while transmitting, it'll keep sending data until
  # the buffer is empty.  If you set verbose to true, send_buffer()
  # will display a running stream of transmitted data to STDOUT.
  def send_buffer(verbose=false)
    if @message.length > 0
      self.transmit()
      send_length=@message.length
      send_start=Time.now()
      show=""
      while @message.length > 0
        @m.synchronize do
          self.sendcmd("text.add_tx",@message)
          @message=""
        end
        waited=0
        max=@start_wait

        result=""
        while waited<max
          waited=waited+1
          result=self.get_tx_data()
          if result.length > 0
            max=@char_wait
            waited=0
            show=show+result
            if verbose
              puts show
            end
          end
          sleep 1
        end
      end
    end
    self.receive()
    send_end=Time.now()
    puts "#{send_length} characters sent in #{(send_end-send_start).to_i} seconds, #{((((send_length/(send_end.to_f-send_start.to_f))*10)+0.5).to_i)/10.to_f} chars/sec." if @debug
    return show
  end

  # Add a string of text to the outgoing buffer.  If you want carriage
  # returns, you must supply them as part of the text (ie, "foo\n").
  # This text is not sent until you call send_buffer(), unless
  # send_buffer() is already running.
  def add_tx_string(text)
    @m.synchronize do
      @message=@message+text
    end
    return @message
  end

  # Return the modem signal quality in the range [0:100] (immediate).
  def quality
    return self.sendcmd("modem.get_quality")
  end

  # Search upwards for a signal (immediate).
  def search_up
    return self.sendcmd("modem.search_up")
  end

  # Search downwards for a signal (immediate).
  def search_down
    return self.sendcmd("modem.search_down")
  end

  # Get current carrier (use this when you want to know what the
  # carrier actually *is* right at this moment, as opposed to what you
  # last set it to (it can drift if AFC is on, or the user clicks the
  # waterfall)).
  def get_carrier
    return self.sendcmd("modem.get_carrier")
  end

  # Return the received data accumulated since the last time you
  # asked.
  def get_rx_data
    return self.sendcmd("rx.get_data")
  end

  # Return the tranmitted data accumulated since the last time you
  # asked.
  def get_tx_data
    return self.sendcmd("tx.get_data")
  end

  # Clear FLDigi's incoming data buffer (you probably don't want to do
  # this, except *possibly* the first time you connect).
  def clear_rx_data
    return self.sendcmd("text.clear_rx")
  end

  # Clear any buffered untransmitted data (as with clear_rx_data(),
  # this is something you'll use sparingly, if ever).
  def clear_tx_data
    return self.sendcmd("text.clear_tx")
  end

  # Clear out the internal buffered message.  This clears the internal
  # object's message queue, but does not change what may or may not be
  # queued in FLDigi for transmission (clear_tx_data() does that).
  def clear_message
    @m.synchronize do
      @message=""
    end
  end

  # Return a list of valid modems supported by FLDigi.  Note that not
  # all modems make sense and/or will work.  Like Feld Hell, for
  # example.  Or the Wefax modes.  And not all modes are 8-bit-clean.
  def list_modems
     return self.sendcmd("modem.get_names")
  end

  # Return a list of supported API calls (this is mostly for
  # development).
  def list_api
    return self.sendcmd("fldigi.list")
  end
  
  # Setup for propnet.  You must call config() one time after this
  # before propnet() can be called as many times as desired.  If
  # @band, @grid, @phg, or @call changes between calls to propnet(),
  # this method (and config()) must be called again.
  def propnet_config
    if @call and @grid and @band and @phg
      
      # We don't want the carrier wandering around while doing
      # propnet.
      @afc=false

      # The carrier for North America is 1500hz.  Might be (probably
      # is) different for other places.  ToDo: fix this so it's
      # user-settable.
      @carrier=1500

      # Transmit frequencies are pre-defined by the propnet folks.
      case @band.to_i
      when 80
        @dial_freq=3598200
        @fsym="h0"
      when 40
        @dial_freq=7103200
        @fsym="hd"
      when 30
        @dial_freq=10138900
        @fsym="hg"
      when 20
        @dial_freq=14097000
        @fsym="hk"
      when 17
        @dial_freq=18105000
        @fsym="ho"
      when 15
        @dial_freq=21098000
        @fsym="hr"
      when 12
        @dial_freq=24924000
        @fsym="hu"
      when 10
        @dial_freq=28118800
        @fsym="hy"
      when 6
        @dial_freq=50291000
        @fsym="vb"
      else
        self.error("Invalid propnet band: #{band}")
        return false
      end

      # Figure out how long to sleep based on the supplied PHG value.
      if @phg[7,1].to_i==0
        @delay=nil
      else
        @delay=3600/(@phg[7,1].to_i)
      end

      # Construct the actual string to be sent.
      tmp="#{@call.upcase}>#{@fsym}:[#{@grid}]#{@phg}/"
      tmp=tmp+'^'+(Digest::CRC16CCITT.hexdigest(tmp)).upcase
      @phgtext="FOR INFO: http://www.PropNET.org\n"+tmp
    end
  end

  # Queue the pre-built PropNET packet (must call propnet_config() and
  #  config() first).  Requires @grid, @call, @band, and @phg to be
  #  set.  Call send_buffer() after to start the actual transmission.
  def propnet
    self.add_tx_string(@phgtext)
  end

  # Queues up a CQ call.  Requires that @call be previously set, else
  # returns false.  Call send_buffer() after to begin transmission.
  def cq
    if @call
      self.add_tx_string("CQ CQ CQ de #{@call} #{@call} #{@call} pse k")
      return true
    else
      self.error("Unable to queue CQ string.")
      return false
    end
  end

end
