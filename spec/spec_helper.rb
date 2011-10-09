$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'xmlrpc-streaming'
require 'ruby-prof'
# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec::Matchers.define :answer_to do |method|
  match do |obj|
    obj.respond_to?(method)
  end
end
  
RSpec.configure do |config| 
  
end