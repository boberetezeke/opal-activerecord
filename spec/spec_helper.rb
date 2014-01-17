require 'opal-rspec'
require 'opal-activerecord'

module TestUnitHelpers
  def assert_equal actual, expected
    actual.should == expected
  end
end

RSpec.configure do |config|
  config.include TestUnitHelpers
end

