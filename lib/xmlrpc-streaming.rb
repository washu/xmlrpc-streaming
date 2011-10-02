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

# Add a to_io method to existing base64 class
class << XMLRPC::Base64
  def to_io
    StringIO.new(@str)
  end
end

module XMLRPC
  class Client
    
    
    def set_debug(stream)
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
      resp = client.request(req) do |res|
        res.read_body do |b|
          sink.write(b)
        end
        sink.close
        sink.open
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
      
      # TODO
      # Write the request to the file to stream out
      request_message.write '<?xml version="1.0"?><methodCall><methodName>'
      request_message.write method
      request_message.write '</methodName><params>'
      # Serialize args here
      request_message.write '</params></methodCall>'
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
        raise "Wrong content-type (received '#{ct}' but expected 'text/xml') *Use set_debug for details"
      end
      
      # Parse the body up to the correct format and recalc size
      
      expected = resp["Content-Length"] || "<unknown>"
      if data.nil? or data.size == 0
        s = data.size
        data.unlink
        raise "Wrong size. Was #{s}, should be #{expected}"
      elsif expected != "<unknown>" and expected.to_i != data.size and resp["Transfer-Encoding"].nil?
        s = data.size
        data.unlink
        raise "Wrong size. Was #{s}, should be #{expected}"
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
      
      # TODO Parse the response stream with the tempfile as the source
      # convert base64 objects to TempFiles for reading, based on wether we should adapt it
      
      # Return the TempFile
      return data
    end
    
    
  end
end