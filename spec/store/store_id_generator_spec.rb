require "spec_helper"

describe StoreIdGenerator do
  it "initializes a generator from a stored string and generates the same id as a new generator" do
    expect(StoreIdGenerator.new("1").next_id).to eq(StoreIdGenerator.new.next_id)
  end

  describe "#next_id" do
    it "returns an object of class StoreId" do
      expect(subject.next_id.class).to eq(StoreId)
    end

    it "two calls to next_id are not equal" do
      expect(subject.next_id).not_to eq(subject.next_id)
    end
  end

  describe "#to_json" do
    it "creates json for StoreIdGenerator state" do
      expect(StoreIdGenerator.new.to_json).to eq("{\"next_id\":1}")
    end
  end

  describe ".new_from_json" do
    it "creates a new store id generator from json" do
      expect(StoreIdGenerator.new_from_json("{\"next_id\":1}")).to eq(StoreIdGenerator.new("1"))
    end
  end
end
