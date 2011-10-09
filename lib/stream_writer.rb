#
# Stream Writer, will write out the XMLRPC data to an IO object
#
# Add a to_io method to existing base64 class
class << XMLRPC::Base64
  def to_io
    StringIO.new(@str)
  end
end

module XMLRPC
    class StreamWriter
        
        # Create a write with a given IO
        def initialize(io)
          @io = io
        end
        
        def methodCall(name, *params)
          @io << '<?xml version="1.0"?><methodCall><methodName>'
          @io << name
          @io << '</methodName><params>'
          params.each do |param|
            conv2value(param)
          end
          @io << '</params></methodCall>'
        end
        
        
        private
        
        def text(txt)
          cleaned = txt.dup
          cleaned.gsub!(/&/, '&amp;')
          cleaned.gsub!(/</, '&lt;')
          cleaned.gsub!(/>/, '&gt;')
          cleaned
        end
        
        def write_tag(tag,value)
          @io << "<value><#{tag}>"
          @io << text(value)
          @io << "</#{tag}></value>"
        end
        
        def write_base64(data_stream)
          @io << "<value><base64>"
            # We read 3 at a time pushed to the file
            # so we dont load the entire file into memory and we ensure the proper end coding sequence
            while (buf = data_stream.read(3)) != nil do
              @io << [buf].pack('m').chop
            end
          @io << "</base64></value>"
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
              if Config::ENABLE_NIL_CREATE
                @io << "<nil/>"
              else
                raise "Wrong type NilClass. Not allowed!"
              end

            when Float
              write_tag "double", param.to_s

            when Struct
              @io << "<value><struct>"
              param.members.each do |key|
                value = param[key]
                @io << "<member>"
                write_tag "name",key.to_s
                con2value(vaue)
                @io << "</member></value>"
              end
              @io << "/struct>"

            when Hash
              # TODO: can a Hash be empty?
              @io << "<value><struct>"

              param.each do |key, value|
                @io << "<member>"
                write_tag "name", key.to_s
                conv2value(value)
                @io << "</member>"
              end
              @io << "</struct></value>"

            when Array
              # TODO: can an Array be empty?
              @io << "<value><array>"
              @io << "<data>"
              param.each do |elem|
                conv2value(elem)
              end
              @io << "</data>"
              @io << "</array></value>"

            when Time, Date, ::DateTime
              write_tag "dateTime.iso8601", param.strftime("%Y%m%dT%H:%M:%S")

            when XMLRPC::DateTime
              write_tag "dateTime.iso8601",format("%.4d%02d%02dT%02d:%02d:%02d", *param.to_a)

            when XMLRPC::Base64
              write_base64(param.to_io)
              
            when IO, response_to?(:read)
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