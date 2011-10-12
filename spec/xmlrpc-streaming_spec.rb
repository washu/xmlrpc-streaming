require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "XmlrpcStreaming" do
  
  it "should create an instance with has values" do
    client = XMLRPC::Client.new2 "http://me@test.com/RPC2"
    client.user.should == "me"
  end
  it "should send a body async" do
    client = XMLRPC::Client.new2 "http://time.xmlrpc.com/RPC2"
    proxy = client.proxy_async("currentTime")
    t = proxy.getCurrentTime.to_time
    t.should_not  == Time.now
  end
  it "should send a body sync" do
    client = XMLRPC::Client.new2 "http://time.xmlrpc.com/RPC2"
    proxy = client.proxy("currentTime")
    proxy.getCurrentTime.to_time.should_not == Time.now
  end
  
  it "should add a to_io method to base64 class" do
    base64 = XMLRPC::Base64.new("dkjfkdjhfkdjhfkdhfkjdhkj")
    base64.to_io.should answer_to(:read)
  end
  
  it "should add a base64 initializer that handles IO objects" do
    base64 = XMLRPC::Base64.new(File.open(File.expand_path(File.dirname(__FILE__) + '/spec_helper.rb')))
    base64.should_not be_nil
  end
  
  it "should set base64 to_io to return an IO object when given one" do
    base64 = XMLRPC::Base64.new(File.open(File.expand_path(File.dirname(__FILE__) + '/spec_helper.rb')))
    base64.to_io.should be_kind_of(IO)
  end
  
  it "should call wordpress for testing" do
    client = XMLRPC::Client.new2 "http://salsxmltest.wordpress.com/xmlrpc.php"
    m = client.call "wp.getUsersBlogs", "washu214", "abc123", File.open(File.expand_path(File.dirname(__FILE__) + '/spec_helper.rb'))
    m.should_not be_empty
    puts m.inspect
  end
  
  it "should upload a base64 object to wordpress" do
    pending("Create a blog post with a large image")
    #blogid 28060656
    #https://salsxmltest.wordpress.com/xmlrpc.php
  end

  it "should encode data the same as the original encoder" do
    creater = XMLRPC::Create.new
    io_block = ''
    streamer = XMLRPC::StreamWriter.new io_block
    doc = creater.methodCall "test", [1,2,3], { :key=> 1, :d => 'v', :x => ['a','b'] }
    # Strip the \n off of the document
    doc.chop!
    streamer.methodCall "test", [1,2,3], { :key=> 1, :d => 'v', :x => ['a','b'] }
    io_block.should == doc
  end

  it "should encode data the same as the original with a time object" do
    creater = XMLRPC::Create.new
    io_block = ''
    streamer = XMLRPC::StreamWriter.new io_block
    doc = creater.methodCall "test", Time.now
    # Strip the \n off of the document
    doc.chop!
    streamer.methodCall "test", Time.now
    io_block.should == doc
  end

  it "should encode data the same as the original with a Date object" do
    creater = XMLRPC::Create.new
    io_block = ''
    streamer = XMLRPC::StreamWriter.new io_block
    doc = creater.methodCall "test", Date.today
    # Strip the \n off of the document
    doc.chop!
    streamer.methodCall "test", Date.today
    io_block.should == doc
  end

  it "should encode data the same as the original with a Marshalable object" do
    klass = Class.new do
      include XMLRPC::Marshallable
      attr_accessor :name, :date
    end
    Object.const_set 'Testable', klass
    creater = XMLRPC::Create.new
    io_block = ''
    streamer = XMLRPC::StreamWriter.new io_block
    doc = creater.methodCall "test", Testable.new
    # Strip the \n off of the document
    doc.chop!
    streamer.methodCall "test", Testable.new
    io_block.should == doc
  end

  it "should encode data the same as the original with a Base64 object" do
    creater = XMLRPC::Create.new
    io_block = ''
    b64 = XMLRPC::Base64.new 'testing junk'
    streamer = XMLRPC::StreamWriter.new io_block
    doc = creater.methodCall "test", b64
    # Strip the \n out as the original will include a \n after a base64 object
    doc.gsub!(/\n/,'')
    streamer.methodCall "test", b64
    io_block.should == doc
  end  

  it "should encode data the same as the original with a Base64 object" do
    creater = XMLRPC::Create.new
    io_block = ''
    b64 = XMLRPC::Base64.new StringIO.new 'testing junk'
    streamer = XMLRPC::StreamWriter.new io_block
    doc = creater.methodCall "test", b64
    # Strip the \n out as the original will include a \n after a base64 object
    doc.gsub!(/\n/,'')
    streamer.methodCall "test", b64
    io_block.should == doc
  end  
  
  it "should upload a large binary object and not run out of memory" do
    pending("add large file upload test")
  end
  
end
