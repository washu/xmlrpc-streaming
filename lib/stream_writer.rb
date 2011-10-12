#
# Stream Writer, will write out the XMLRPC data to an IO object
#

module XMLRPC
    class StreamWriter
        
        WRITE_BUFFER_SIZE = 33972
        # Create a write with a given IO
        def initialize(io)
          @io = io
        end
        def has_streams?
          @had_a_stream ||= false
          @had_a_stream
        end
        def methodCall(name, *params)
          @io << '<?xml version="1.0" ?><methodCall><methodName>'
          @io << name
          @io << '</methodName><params>'
          params.each do |param|
            @io << "<param>"
            conv2value(param)
            @io << "</param>"
          end
          @io << '</params></methodCall>'
        end
        
        
        private
        
        # escape some text
        def text(txt)
          cleaned = txt.dup
          cleaned.gsub!(/&/, '&amp;')
          cleaned.gsub!(/</, '&lt;')
          cleaned.gsub!(/>/, '&gt;')
          cleaned
        end
        
        # write a tag with value tags around it
        def write_tag(tag,value)
          @io << "<value><#{tag}>#{text(value)}</#{tag}></value>"
        end
                
        # write teh tag directly without the value tags
        def write_elem(tag, value)
          @io << "<#{tag}>#{text(value)}</#{tag}>"
        end
                
        def write_with_children(tag,sub = nil)
          @io << "<value><#{tag}>"
          @io<< "<#{sub}>" if sub
          yield if block_given?
          @io<< "</#{sub}>" if sub
          @io << "</#{tag}></value>" 
        end
        
        # write base64 data to the output stream
        def write_base64(data_stream)
          write_with_children "base64" do
            while (buf = data_stream.read(WRITE_BUFFER_SIZE)) != nil do
              @io << [buf].pack('m').chop
            end
          end
        end
        
        def conv2value(param)
            case param
            when Fixnum, Bignum
              # XML-RPC's int is 32bit int, and Fixnum also may be beyond 32bit
              if Config::ENABLE_BIGINT
                write_tag "i4",param.to_s
              else
                if param >= -(2**31) and param <= (2**31-1)
                  write_tag "i4", param.to_s
                else
                  raise "Bignum is too big! Must be signed 32-bit integer!"
                end
              end
            when TrueClass, FalseClass
              write_tag "boolean", param ? "1" : "0"

            when Symbol
              write_tag "string", param.to_s

            when String
              write_tag "string", param

            when NilClass
              @io << "<nil/>" if Config::ENABLE_NIL_CREATE
              raise "Wrong type NilClass. Not allowed!" unless Config::ENABLE_NIL_CREATE

            when Float
              write_tag "double", param.to_s

            when Struct
              write_with_children "struct" do
                param.members.each do |key|
                  value = param[key]
                  @io << "<member>"
                  write_elem("name",key.to_s)
                  con2value(value)
                  @io << "</member>"
                end
              end

            when Hash
              write_with_children "struct" do
                param.each do |key, value|
                  @io << "<member>"
                  write_elem("name", key.to_s)
                  conv2value(value)
                  @io << "</member>"
                end
              end

            when Array
              write_with_children "array","data" do
                param.each do |elem|
                  conv2value(elem)
                end
              end

            when Time, Date, ::DateTime
              write_tag "dateTime.iso8601", param.strftime("%Y%m%dT%H:%M:%S")

            when XMLRPC::DateTime
              write_tag "dateTime.iso8601",format("%.4d%02d%02dT%02d:%02d:%02d", *param.to_a)

            when XMLRPC::Base64
              write_base64(param.to_io)
              
            when IO, respond_to?(:read)
              @had_a_stream = true
              write_base64(param)

            else
              if XMLRPC::Config::ENABLE_MARSHALLING and param.class.included_modules.include? XMLRPC::Marshallable
                # convert Ruby object into Hash
                ret = {"___class___" => param.class.name}
                param.instance_variables.each  do |v|
                  name = v[1..-1]
                  val = param.instance_variable_get(v)

                  if val.nil?
                    ret[name] = val if XLMRPC::Config::ENABLE_NIL_CREATE
                  else
                    ret[name] = val
                  end
                end
                return conv2value(ret)
              else
                ok, pa = wrong_type(param)
                if ok
                  return conv2value(pa)
                else
                  raise "Wrong type!"
                end
              end
            end
        end

        def wrong_type(value)
          false
        end
    end
end