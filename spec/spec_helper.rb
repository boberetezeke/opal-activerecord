if RUBY_ENGINE == "opal"
  require 'opal-rspec'
  require 'opal-activerecord'
else
  require_relative '../opal/active_record/core'
end

module TestUnitHelpers
  def assert_equal actual, expected
    actual.should == expected
  end
end

RSpec.configure do |config|
  config.include TestUnitHelpers
end

