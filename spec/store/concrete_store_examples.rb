
RSpec.shared_examples "a concrete store" do
  describe "#create" do
    it "creates a record" do
      subject.create(Thing, "things", Record.new({"attr" => 1}))
      expect(subject.all_for_table("things")).to eq([{"attr" => 1, "id" => StoreId.new(1)}])
    end

    it "creates two records" do
      subject.create(Thing, "things", Record.new({"attr" => 1}))
      subject.create(Thing, "things", Record.new({"attr" => 2}))
      expect(subject.all_for_table("things")).to eq([
        {"attr" => 1, "id" => StoreId.new(1)},
        {"attr" => 2, "id" => StoreId.new(2)}
      ])
    end
  end

  describe "#update_id" do
    it "updates an id in the store" do
      subject.create(Thing, "things", Record.new({"attr" => 1}))
      subject.update_id(Thing, "things", StoreId.new(1), "1")
      expect(subject.all_for_table("things")).to eq([
        {"attr" => 1, "id" => "1"}
      ])
    end
  end

  describe "#destroy" do
    it "creates two records and destroys one" do
      record_1 = Record.new({"attr" => 1})
      record_2 = Record.new({"attr" => 2})
      record_1_id = subject.create(Thing, "things", record_1)
      subject.create(Thing, "things", record_2)
      record_1.attributes = record_1.attributes.merge("id" => record_1_id)
      subject.destroy(Thing, "things", record_1)
      expect(subject.all_for_table("things")).to eq([
        {"attr" => 2, "id" => StoreId.new(2)}
      ])
    end
  end
end
