require "spec_helper"
require_relative "concrete_store_examples"

class Thing
end

class Record
  attr_accessor :attributes
  def initialize(attributes={})
    @attributes = attributes
  end

  def id
    @attributes["id"]
  end
end

describe ActiveRecord::MemoryStore do
  it_behaves_like "a concrete store"
end

