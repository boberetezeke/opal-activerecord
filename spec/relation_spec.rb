require 'spec_helper'

class Q < ActiveRecord::Base
  has_many :rs
end

class R < ActiveRecord::Base
end

describe ActiveRecord::Relation do
  def create_object(klass, table_name, attributes={})
    a = klass.new(attributes)
    a.id = memory_store.create(klass, table_name, a, {})
    a
  end

  let(:mock_local_storage)  { MockLocalStorage.new }
  let(:memory_store)        { ActiveRecord::LocalStorageStore.new(mock_local_storage) }
  let!(:q1)                 { create_object(Q, "qs", x: 1, y: 3) }
  let!(:q2)                 { create_object(Q, "qs", x: 2, y: 3) }
  let!(:q3)                 { create_object(Q, "qs", x: 2, y: 4) }

  let!(:r1)                 { create_object(R, "rs", z: 1, q_id: q1.id) }
  let!(:r2)                 { create_object(R, "rs", z: 2, q_id: q1.id) }
  let!(:r3)                 { create_object(R, "rs", z: 3, q_id: q2.id) }

  describe "#where" do
    it 'retrieves an array of one record when it matches one attribute' do
      expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(id: q1.id).load).to eq([q1])
    end

    it "retrieves an array of two records when it matches on a different value" do
      expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(x: 2).load).to match_array([q2, q3])
    end

    it "retrieves an array of one record when it matches on two attributes" do
      expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(x: 2, y: 3).load).to match_array([q2])
    end

    it "retrieves an empty array when there are no matches" do
      expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(id: q1.id+100).load).to eq([])
    end
    
    context "when using arel_table" do
      it 'retrieves an array of one record when it matches one attribute' do
        expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(Q.arel_table[:id].eq(q1.id)).load).to eq([q1])
      end

      it "retrieves an array of two records when it matches on a different value" do
        expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(Q.arel_table[:x].eq(2)).load).to match_array([q2, q3])
      end

      it "retrieves an array of one record when it matches on two attributes" do
        expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(Q.arel_table[:x].eq(2).and(Q.arel_table[:y].eq(3))).load).to eq([q2])
      end

      it "retrieves a record when joining two tables" do
        expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').joins(:rs).where(Q.arel_table[:y].eq(3).and(R.arel_table[:z].eq(3))).load).to eq([q2])
      end
    end
  end

  describe "#order" do
    it "retrieves objects in descending order" do
      expect(ActiveRecord::Relation.new(memory_store, Q, 'qs').where(x: 2).order('y desc').load).to eq([q3, q2])
    end
  end
end
