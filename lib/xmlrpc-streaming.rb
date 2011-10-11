=begin
= xmlrpc-streaming.rb
Copyright (C) 2011 by Sal Scotto (sal.scotto@gmail.com)
Released under the same terms of  license as Ruby.

== XMLRPC::Client License
We override several key methods of the original XMLRPC::Client by Michael Neumann
Copyright (C) 2001, 2002, 2003 by Michael Neumann (mneumann@ntecs.de)
Released under the same terms of  license as Ruby.

== Description
This class extends a few key methods of the XMLRPC::Client library 
it treats base64 data differently. It allows you pass in any object
that supports a #read(bytes) method to be used instead of having to provide a
base64 encoded string for binary data. The problem it is trying to solve
is the case of sending a large binary blob over xmlrpc, which consumes large
amounts of ram to not only encoded and represent, but also to decode.
To use transparently

require 'xmlrpc/client'
require 'xmlrpc-streaming'

== Instance Methods
--- XMLRPC::Client#set_debug( output_stream)
    Invokes the call with debug output sent to the provided stream

== Differences
Any place you would normally get or send an XMLRPC::Base64 object
you can instead subsitute an object that supports #read(bytes) in it places
=end


require 'stringio'
require 'xmlrpc/base64'
require 'xmlrpc/client'
require 'tempfile'
require 'stream_writer'

# Add a to_io method to existing base64 class
module XMLRPC
  class Base64
    
    def initialize(str, state = :dec)
      @state = state
      @str = nil
      @stream = false
      case state
      when :enc
        if str.respond_to?(:read)
          @str = str
          @stream = true
        else
          @str = XMLRPC::Base64.decode(str)
        end
      when :dec
        @str = str
        if str.respond_to?(:read)
          @stream = true
        end        
      else
        raise ArgumentError, "wrong argument; either :enc or :dec"
      end
    end
    
    # Create an IO stream out of the data if it isnt a stream already
    # side effect: will call rewind on the stream if it is rewindable
    def to_io
      if @stream
        if @str.respond_to?(:rewind)
          @str.rewind
        end
        @str
      else
        StringIO.new(@str)
      end
    end
    
    # Get the decoded string
    # if theunderlying string is a stream it will rewind before the call
    def decoded
      if @stream
        if @str.respond_to?(:rewind)
          @str.rewind
        end
        @str.read
      else
        @str
      end
    end
    
    # Get the encoded string
    # if the underlying string is a stream will call rewind first
    def encoded
      if @stream
        if @str.respond_to?(:rewind)
          @str.rewind
        end
        Base64.encode(@str.read)
      else
        Base64.encode(@str)
      end
    end
  end
end

module XMLRPC
  class Client
    
=begin
    set_debug_stream stream
    will enable HTTP debuggin to the passed in stream
=end
    def set_debug_stream(stream)
      @debug_stream = stream
    end
    
    def call2_async(method, *args)
      data = do_rpc(true,method,*args)
      parser().parseMethodResponse(data)
    end
    
    def call2(method, *args)
      data = do_rpc(false,method,*args)
      parser().parseMethodResponse(data)
    end
    
    private
    
    # Stream our Request over to the server and save the results in a tempfile
    def post_request(client,path,header,request_file,sink)
      # Post via stream
      req = Net::HTTP::Post.new(path,header)
      req.body_stream = request_file
      sink.binmode
      resp = client.request(req) do |res|
        res.read_body do |b|
          sink.write(b)
        end
        sink.rewind
        sink.size
        sink
      end
      resp
    end
    
    def do_rpc(async,method,*args)
      header = {
       "User-Agent"     =>  USER_AGENT,
       "Content-Type"   => "text/xml; charset=utf-8",
       "Connection"     => (async ? "close" : "keep-alive")
      }
      header["Cookie"] = @cookie        if @cookie
      header.update(@http_header_extra) if @http_header_extra
      if @auth != nil
        # add authorization header
        header["Authorization"] = @auth
      end
      resp = nil
      @http_last_response = nil

      # Construct the request data
      request_message = Tempfile.new('xmlrpc-stream-request')
      data = Tempfile.new("xmlrpc-response-body")
      # Use the streamwrite to write the temp file
      writer = StreamWriter.new(request_message)
      writer.methodCall(method,*args)
      request_message.close
      content_length = request_message.size
      request_message.open
      # get the data size of the request
      header["Content-Length"] = content_length.to_s

      # temp garbage will grow but GC will handle it over the course of 
      # the download/upload so you shouldnt get alocation errors with big files

      resp = nil
      if async
        # use a new HTTP object for each call
        Net::HTTP.version_1_2
        http = Net::HTTP.new(@host, @port, @proxy_host, @proxy_port)
        http.use_ssl = @use_ssl if @use_ssl
        http.read_timeout = @timeout
        http.open_timeout = @timeout
        http.set_debug_output @debug_stream if @debug_stream
        http.start {
          resp = post_request(http,@path,header,request_message,data)
        }
      else
        @http.set_debug_output @debug_stream if @debug_stream
        @http.start if not @http.started?
        resp = post_request(@http,@path,header,request_message,data)
      end
      

      @http_last_response = resp
      
      if resp.code == "401"
        # Authorization Required
        data.unlink
        raise "Authorization failed.\nHTTP-Error: #{resp.code} #{resp.message}"
      elsif resp.code[0,1] != "2"
        data.unlink
        raise "HTTP-Error: #{resp.code} #{resp.message}"
      end
      
      ct = parse_content_type(resp["Content-Type"]).first
      # Some implmentations return application/xml, for faults so lets allow 
      # them for poor implmentations of servers
      if ct !~ /\/xml$/
        data.unlink
        raise "Wrong content-type (received '#{ct}' but expected 'text/xml') *Use set_debug_stream for details"
      end
      
      # Parse the body up to the correct format and recalc size
      # for some reason ruby 1.9.2 on windows, tempfile size is larger than number of bytes written to it
	  # Im no sure why that is
      expected = resp["Content-Length"] || "<unknown>"
      if data.nil? or data.size == 0
        s = data.size
        data.unlink
        raise "Wrong size. Was #{s}, should be #{expected} #{data.read}"
      elsif expected != "<unknown>" and expected.to_i > data.size and resp["Transfer-Encoding"].nil?
        s = data.size
		data.unlink
		raise "Wrong size. Was #{s}, should be #{expected} #{data.read}"
      end
      
      # Copy any cookies sent
      set_cookies = resp.get_fields("Set-Cookie")
      if set_cookies and !set_cookies.empty?
        require 'webrick/cookie'
        @cookie = set_cookies.collect do |set_cookie|
          cookie = WEBrick::Cookie.parse_set_cookie(set_cookie)
          WEBrick::Cookie.new(cookie.name, cookie.value).to_s
        end.join("; ")
      end
      # Return the TempFile
      return data
    end
  end  
end