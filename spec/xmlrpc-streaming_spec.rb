require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "XmlrpcStreaming" do
  it "should create an instance with has values" do
    client = XMLRPC::StreamingClient.new uri: "http://me@test.com/RPC2"
    client.user.should eql("me")
  end
  it "should send a body" do
    client = XMLRPC::StreamingClient.new uri: "http://www.foodlion.com/Search"
    client.call2("search","a")
  end
end
