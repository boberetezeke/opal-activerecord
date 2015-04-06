
require 'spec_helper'

class M < ActiveRecord::Base
  before_save :inc_x
  after_save  :mod_n

  belongs_to :n

  def inc_x
    self.x += 1
  end

  def mod_n
     n.update(y: 2)
  end
end

class N < ActiveRecord::Base
  has_many :ms
end

describe "ActiveRecord::Base" do
  if running_with_real_active_record
    before do
      ActiveRecord::Base.establish_connection(
        adapter:  'sqlite3',
        database: 'test.sqlite3'
      )
      ActiveRecord::Base.connection.create_table("ms") {|t| t.integer :x; t.integer :b_id}
      ActiveRecord::Base.connection.create_table("ns") {|t| t.integer :y}
    end

    after do
      ActiveRecord::Base.connection.drop_table("ms")
      ActiveRecord::Base.connection.drop_table("ns")
    end
  else
    # only set memory_store for opal
    let(:mock_local_storage) { MockLocalStorage.new }
    let(:memory_store) { ActiveRecord::LocalStorageStore.new(mock_local_storage) }
    #let(:memory_store) { ActiveRecord::MemoryStore.new }
    before do
      ActiveRecord::Base.connection = memory_store
    end
  end


  it "should run the before and after save callbacks" do
    n = N.create(y:1)
    m = M.new(n: n, x: 1)

    m.save

    m = M.find(m.id)

    expect(m.x).to eq(2)
    expect(m.n.y).to eq(2)
  end
end

