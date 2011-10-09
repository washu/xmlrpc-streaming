require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "XmlrpcStreaming" do
  it "should create an instance with has values" do
    client = XMLRPC::Client.new2 "http://me@test.com/RPC2"
    client.user.should == "me"
  end
  it "should send a body async" do
    client = XMLRPC::Client.new2 "http://time.xmlrpc.com/RPC2"
    proxy = client.proxy_async("currentTime")
    proxy.getCurrentTime.to_time.should_not  == Time.now
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
    client = XMLRPC::Client.new2 "https://salsxmltest.wordpress.com/xmlrpc.php"
    m = client.call "wp.getUsersBlogs", "washu214", "abc123", File.open(File.expand_path(File.dirname(__FILE__) + '/spec_helper.rb'))
    m.should_not be_empty
  end
  
  it "should upload a base64 object to wordpress" do
    pending("Create a blog post with a large image")
    #blogid 28060656
    #https://salsxmltest.wordpress.com/xmlrpc.php
  end

  it "should upload a large binary object and not run out of memory" do
    pending("add large file upload test")
  end
  
end
