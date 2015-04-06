require 'spec_helper'

class A < ActiveRecord::Base
end

describe ActiveRecord::Relation do
  def create_object(klass, table_name, attributes={})
    a = A.new(attributes)
    a.id = memory_store.create(klass, table_name, a, {})
    a
  end

  let(:mock_local_storage)  { MockLocalStorage.new }
  let(:memory_store)        { ActiveRecord::LocalStorageStore.new(mock_local_storage) }
  let!(:a1)                 { create_object(A, "as", x: 1, y: 2) }
  let!(:a2)                 { create_object(A, "as", x: 2, y: 3) }
  let!(:a3)                 { create_object(A, "as", x: 2, y: 4) }

  describe "#where" do
    it 'retrieves an array of one record when it matches one attribute' do
      expect(ActiveRecord::Relation.new(memory_store, A, 'as').where(id: a1.id).load).to eq([a1])
    end

    it "retrieves an array of two records when it matches on a different value" do
      expect(ActiveRecord::Relation.new(memory_store, A, 'as').where(x: 2).load).to match_array([a2, a3])
    end

    it "retrieves an array of one record when it matches on two attributes" do
      expect(ActiveRecord::Relation.new(memory_store, A, 'as').where(x: 2, y: 3).load).to match_array([a2])
    end

    it "retrieves an empty array when there are no matches" do
      expect(ActiveRecord::Relation.new(memory_store, A, 'as').where(id: a1.id+100).load).to eq([])
    end
  end

  describe "#order" do
    it "retrieves objects in descending order" do
      expect(ActiveRecord::Relation.new(memory_store, A, 'as').where(x: 2).order('y desc').load).to eq([a3, a2])
    end
  end
end
