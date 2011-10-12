require 'xmlrpc/parser'

module XMLRPC
  module StreamParserMixin2
    attr_reader :params
    attr_reader :method_name
    attr_reader :fault
    attr_accessor :use_streams
    def initialize(*a)
      super(*a)
      @params = []
      @values = []
      @val_stack = []

      @names = []
      @name = []

      @structs = []
      @struct = {}

      @method_name = nil
      @fault = nil

      @data = nil
      @working_tag = nil
    end

    def startElement(name, attrs=[])
      @data = nil
      case name
      when "value"
        @value = nil
      when "nil"
        raise "wrong/unknown XML-RPC type 'nil'" unless Config::ENABLE_NIL_PARSER
        @value = :nil
      when "array"
        @val_stack << @values
        @values = []
      when "struct"
        @names << @name
        @name = []
        @structs << @struct
        @struct = {}
      end
      @working_tag = name
    end

    def endElement(name)
      @data ||= ""
      if name.eql?("base64") and @use_streams
        # Decode the file data into a new temp file and set the response as a stream
        # the caller will get an IO Object as a result. Only do this if we flagged ourselves
        # as 'recevied an io stream'
      else
        @data = Convert.base64(@data)
      end  
      case name
      when "string"
        @value = @data
      when "i4", "int"
        @value = Convert.int(@data)
      when "boolean"
        @value = Convert.boolean(@data)
      when "double"
        @value = Convert.double(@data)
      when "dateTime.iso8601"
        @value = Convert.dateTime(@data)
      when "base64"
        @value = @data
      when "value"
        @value = @data if @value.nil?
        @values << (@value == :nil ? nil : @value)
      when "array"
        @value = @values
        @values = @val_stack.pop
      when "struct"
        @value = Convert.struct(@struct)

        @name = @names.pop
        @struct = @structs.pop
      when "name"
        @name[0] = @data
      when "member"
        @struct[@name[0]] = @values.pop

      when "param"
        @params << @values[0]
        @values = []

      when "fault"
        @fault = Convert.fault(@values[0])

      when "methodName"
        @method_name = @data
      end

      @data = nil
    end

    def character(data)
      if @data
        @data << data
      else
        if @working_tag.eql?("base64")
          @data = Tempfile.new('xmlrpc-stream-base64-data')
          @data.binmode
        else
          @data = data
        end
      end
    end
  end # module StreamParserMixin

  module XMLParser
    class REXMLStreamParser2 < AbstractStreamParser
      def initialize(streamed = false)
        require "rexml/document"
        @parser_class = StreamListener
      end
      def use_streams=(arg)
        @use_streams = arg
      end
      def parseMethodResponse(str)
        parser = @parser_class.new
        parser.user_streams = @use_streams
        parser.parse(str)
        raise "No valid method response!" if parser.method_name != nil
        if parser.fault != nil
          # is a fault structure
          [false, parser.fault]
        else
          # is a normal return value
          raise "Missing return value!" if parser.params.size == 0
          raise "Too many return values. Only one allowed!" if parser.params.size > 1
          [true, parser.params[0]]
        end
      end

      def parseMethodCall(str)
        parser = @parser_class.new
        parser.user_streams = @use_streams
        parser.parse(str)
        raise "No valid method call - missing method name!" if parser.method_name.nil?
        [parser.method_name, parser.params]
      end
      
      class StreamListener
        include StreamParserMixin2

        alias :tag_start :startElement
        alias :tag_end :endElement
        alias :text :character
        alias :cdata :character

        def method_missing(*a)
          # ignore
        end
        
        def parse(str)
          parser = REXML::Document.parse_stream(str, self)
        end
      end
    end
  end
end
