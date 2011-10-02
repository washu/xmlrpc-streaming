require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "XmlrpcStreaming" do
  it "should create an instance with has values" do
    client = XMLRPC::Client.new2 "http://me@test.com/RPC2"
    client.user.should == "me"
  end
  it "should send a body async" do
    client = XMLRPC::Client.new2 "http://www.foodlion.com/Search"
    #client.set_debug $stderr
    client.call2_async "search","a"
  end
  it "should send a body sync" do
    client = XMLRPC::Client.new2 "http://www.foodlion.com/Search"
    #client.set_debug $stderr
    client.call2 "search","a"
  end
  
  it "should encode base64 as an io object" do
    pending "add test for base64 as stream"
  end
  
  it "should decode base64 into a stream" do
    pending "Test base64.to_io"
  end
  
  it "should handle base64 object as stream" do
    pending "test base64.to_io reads properly"
  end
  
  it "should return a base64 object when called with a base64 object" do
    pending "ensure when gien a base64 object we return one"
  end
  
  it "should handle an readable object for streaming" do
    pending "when given an object that responds to read, read in chunks and add to temp file"
  end
  
  it "should pull parse the repsonse" do
    pending "use a pull parser for data, ensure we dont DOM the xml"
  end
  
end
