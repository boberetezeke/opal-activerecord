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
    require_relative '../opal/active_record/core_ext/string'
    require_relative '../opal/active_record/local_storage'
    require_relative '../opal/active_record/store/abstract_store'
    require_relative '../opal/active_record/store/local_storage_store'
    require_relative '../opal/active_record/store/memory_store'
    require_relative '../opal/active_record/association'
    require_relative '../opal/active_record/collection_proxy'
    require_relative '../opal/active_record/relation'
    require_relative '../opal/active_record/arel'
    require_relative '../opal/active_record/callbacks'
    require_relative '../opal/active_record/core'
    # uncomment only when running  in MRI
    require 'json'
  end
end

class MockLocalStorage
  attr_reader :storage
  def initialize
    @storage = {}
  end

  def set(name, value)
    if value.is_a?(Hash) || value.is_a?(Array)
      @storage[name] = value.dup
    else
      @storage[name] = value
    end
  end

  def get(name)
    @storage[name]
  end

  def remove(name)
    @storage.delete(name)
  end

  def to_s
    @storage.inspect
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

