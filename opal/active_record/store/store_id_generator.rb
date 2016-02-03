class StoreIdGenerator
  def self.new_from_json(json)
    json_hash = JSON.parse(json)
    new(json_hash["next_id"])
  end

  def initialize(next_id_str="1")
    @next_id = next_id_str.to_i
  end

  def next_id
    id = StoreId.new(@next_id)
    @next_id += 1
    id
  end

  def next_id_value
    @next_id
  end

  def ==(other)
    return false unless other.is_a?(self.class)

    self.next_id_value == other.next_id_value
  end

  def to_json
    {"next_id" => @next_id}.to_json
  end
end
