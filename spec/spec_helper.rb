
if ENV['run_with_real_active_record']
  Bundler.require(:test)
  require "active_record"
else
  if RUBY_ENGINE == "opal"
    require 'opal-rspec'
    require 'opal-activerecord'
  else
    require_relative '../opal/active_record/core'
  end
end


module TestUnitHelpers
  def assert_equal actual, expected
    actual.should == expected
  end
end

RSpec.configure do |config|
  config.include TestUnitHelpers
end

def running_with_real_active_record
  ENV['run_with_real_active_record']
end

