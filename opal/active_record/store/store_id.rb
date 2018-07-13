class StoreId
  include Comparable

  attr_reader :id_value
  def initialize(id_value)
    @id_value = id_value.to_s
    @resolved = false
  end

  def ==(other)
    if @resolved
      self.to_i == other.to_i
    else
      return false unless other.is_a?(self.class)

      @id_value == other.id_value
    end
  end

  def hash
    @id_value.hash + (@resolved ? "t" : "f")
  end

  def dup
    self.class.new(@id_value)
  end

  def to_s
    if @resolved
      @id_value.to_s
    else
      "T-#{@id_value}"
    end
  end

  def resolve_to(id_value)
    @id_value = id_value
    @resolved = true
    self
  end

  def to_i
    if @resolved
      @id_value.to_i
    else
      -30000 + @id_value.to_i
    end
  end

  #
  # NOTE: for the purposes of comparison, these values will be negative
  #       that way, they will not be comparable to a server ID value
  #
  def <=>(other)
    our_id_value = self.to_i
    if other.is_a?(self.class)
      other_id_value = other.to_i
    else
      other_id_value = other.to_i
    end

    our_id_value.<=>(other_id_value)
  end
end


=begin
class String
  def <=>(other)
    if other.is_a?(StoreId)
      StoreId.new(self).<=>(other)
    else
      super
    end
  end
end
=end
