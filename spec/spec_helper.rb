if ENV['run_with_real_active_record']
  puts "running with real active record"
  # uncomment only when running from command line: run_with_real_active_record=true rspec spec
  # Bundler.require(:test)
  # require "active_record"
else
  if RUBY_ENGINE == "opal"
    puts "running with Opal"
    require 'opal-rspec'
    require 'opal-activerecord'
  else
    puts "running with MRI"
    require_relative '../opal/active_record/core'
    # uncomment only when running  in MRI
    require 'json'
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

