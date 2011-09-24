=begin
= xmlrpc/streaming_client.rb
Copyright (C) 2011 by Sal Scotto (sal.scotto@gmail.com)
Released under the same terms of  license as Ruby.

== XMLRPC::Client License
We make heavy use of the original XMLRPC::Client by Michael Neumann
Some cases copying his original methods, other cases modifying them
Copyright (C) 2001, 2002, 2003 by Michael Neumann (mneumann@ntecs.de)
Released under the same terms of  license as Ruby.


= Classes
* ((<XMLRPC::StreamingClient>))

= XMLRPC::StreamingClient
== Synopsis
  require "xmlrpc-streaming"
  
  server = XMLRPC::StreamingClient.new host: "host", :path "/RPC2", user: "user", password: "somepass"
  OR
  server = XMLRPC::StreamingClient.new uri: "http://user:password@host/path"

== Description
This class reuses a lot of the XMLRPC::Client library such as the proxy
class, it is however more limited, it doesnt support the async interface
and treats base64 data and dates differently. Instead of passing in a base64
encoded data for instance, you pass in an IO object to be read. Under the covers
it will convert Date and Time objects to the correct XMLRPC::Datetime object
both in and out of the response. We also only use the Hash constructor

== Class Methods
--- XMLRPC::StreamingClient.new {}
    case-insensitive keys we look for
    * host
    * path
    * port
    * proxy_host
    * proxy_port
    * user
    * password
    * use_ssl
    * timeout
    * uri (if set we will not check host, path, port, user, password or use_ssl)

=end

require 'xmlrpc/client'
require 'uri'
require 'tempfile'

module XMLRPC
    class StreamingClient
        USER_AGENT = "XMLRPC::StreamingClient (Ruby #{RUBY_VERSION})"
        # add additional HTTP headers to the request
        attr_accessor :http_header_extra
        # makes last HTTP response accessible
        attr_reader :http_last_response
        # Cookie support
        attr_accessor :cookie
        attr_reader :timeout, :user, :password, :host
        
        def initialize args
          args.each do |k,v|
            instance_variable_set("@#{k}", v) unless v.nil?
          end if args.is_a? Hash
          if @uri != nil
            uri = URI.parse(@uri)
            @port = uri.port
            @user = uri.user
            @password = uri.password
            @path = uri.path
            @host = uri.host
            @use_ssl = false unless uri.scheme.eql?("https")
          else
            @host = "localhost" if @host.nil?
            @path = "/RPC2" if @path.nil?
            @use_ssl = false if @use_ssl.nil?
          end
          
          set_auth
          
          @http_header_extra = nil
          @http_last_response = nil
          @cookie = nil
          @timeout = 30 if @timeout.nil?
          
          if @use_ssl
            require 'net/https'
            @port = 443 if @port.nil?
          else
            @port = 80 if @port.nil?
          end
          
          @proxy_host ||= 'localhost' unless @proxy_port.nil?
          @proxy_port ||= 8080 unless @proxy_host.nil?
          
          @post = @port.to_i
          @proxy_port = @proxy_port.to_i unless @proxy_port.nil?
          
          # Setup base HTTP Object
          Net::HTTP.version_1_2
          @http = Net::HTTP.new(@host, @port, @proxy_host, @proxy_port)
          @http.use_ssl = @use_ssl if @use_ssl
          @http.read_timeout = @timeout
          @http.open_timeout = @timeout
        end
        
        # Directly copied form XMLRPC::Client
        def timeout=(new_timeout)
          @timeout = new_timeout
          @http.read_timeout = @timeout
          @http.open_timeout = @timeout
        end
        
        # Directly copied form XMLRPC::Client
        def user=(new_user)
          @user = new_user
          set_auth
        end

        # Directly copied form XMLRPC::Client
        def password=(new_password)
          @password = new_password
          set_auth
        end
                
        # Directly copied form XMLRPC::Client
        def proxy(prefix=nil, *args)
          Client::Proxy.new(self,prefix, args, :call)
        end
        # Directly copied form XMLRPC::Client
        def proxy2(prefix=nil, *args)
          Client::Proxy.new(self,prefix, args, :call2)
        end
        
        # Directly copied form XMLRPC::Client
        def call(method, *args)
          ok, params = call2(method,*args)
          if ok
            params
          else
            raise params
          end
        end
        # Directly copied form XMLRPC::Client        
        def multicall(*methods)
          ok, params = multicall2(*method)
          if ok
            params
          else
            raise params
          end
        end
        
        def call2(method, *args)
          do_rpc(method,*args)
        end

        def multicall2(*methods)
          gen_multicall(methods)
        end
        
        
        private
        # Directly copied form XMLRPC::Client
        def set_auth
          if @user.nil?
            @auth = nil
          else
            a =  "#@user"
            a << ":#@password" if @password != nil
            @auth = ("Basic " + [a].pack("m")).chomp
          end
        end        
        # Directly copied form XMLRPC::Client
        def gen_multicall(methods=[])
          meth = :call2
          ok, params = self.send(meth, "system.multicall",
            methods.collect {|m| {'methodName' => m[0], 'params' => m[1..-1]} }
          )
          if ok
            params = params.collect do |param|
              if param.is_a? Array
                param[0]
              elsif param.is_a? Hash
                XMLRPC::FaultException.new(param["faultCode"], param["faultString"])
              else
                raise "Wrong multicall return value"
              end
            end
          end
          return ok, params
        end
        
        # do the actual RPC call
        def do_rpc(method,*args)
          header = {
           "User-Agent"     =>  USER_AGENT,
           "Content-Type"   => "text/xml; charset=utf-8",
           "Connection"     => "keep-alive"
          }
          header["Cookie"] = @cookie        if @cookie
          header.update(@http_header_extra) if @http_header_extra
          # set auth if needed
          if @auth != nil
            # add authorization header
            header["Authorization"] = @auth
          end
          # clear response
          resp = nil
          @http_last_response = nil
          # Construct data in tmp file for send
          tfile = Tempfile.new('foo')
          tfile.write("Testing some shit ")
          tfile.write ["str Some binary data"].pack("m")
          tfile.close
          content_length = tfile.size
          puts "Content Length #{content_length}"
          tfile.open
          # get the data size of the request
          header["Content-Length"] = content_length.to_s
          #@http.set_debug_output $stderr
          @http.start if not @http.started?
          # Post via stream
          req = Net::HTTP::Post.new(@path,header)
          req.body_stream = tfile
          resp = @http.request(req)
          puts resp.value
        end
        
        
        
        
    end
end