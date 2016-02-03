require "spec_helper"

describe StoreId do
  it "is a value object" do
    expect(StoreId.new(1)).to eq(StoreId.new(1))
  end

  it "when unresolved, it fails comparison with another type of object" do
    expect(StoreId.new(1)).not_to eq(1)
  end

  it "when resolved it compares with integers" do
    store_id = StoreId.new(1)
    store_id.resolve_to(2)
    expect(store_id).to eq(2)
  end

  it "when resolved it compares with strings" do
    store_id = StoreId.new(1)
    store_id.resolve_to(2)
    expect(store_id).to eq("2")
  end

  it "returns a string of T-n where n is the id value" do
    expect(StoreId.new(1).to_s).to eq("T-1")
  end

  it "resolves to a non local value" do
    expect(StoreId.new(1).resolve_to(2).to_s).to eq("2")
  end

  it "handles comparison" do
    expect(StoreId.new(1) < StoreId.new(2)).to be_truthy
  end
end
