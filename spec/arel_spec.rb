require 'spec_helper'

class A < ActiveRecord::Base
end

describe Arel do
  describe Arel::SelectManager do
    let(:connection)      { double('connection') }
    let(:select_manager)  { Arel::SelectManager.new(connection, A, "as") }


end

  describe Arel::Nodes::Ordering do
    it "handles the simple case of one field" do
      orders = Arel::Nodes::Ordering.new('table_name', 'field1').orders
      expect(orders.size).to eq(1)
      expect(orders.first.field_name).to eq('field1')
      expect(orders.first.direction).to  eq(Arel::Nodes::Ordering::Order::ASCENDING)
    end

    it "handles the case of a field and a ascending direction" do
      orders = Arel::Nodes::Ordering.new('table_name', 'field1 asc').orders
      expect(orders.size).to eq(1)
      expect(orders.first.field_name).to eq('field1')
      expect(orders.first.direction).to  eq(Arel::Nodes::Ordering::Order::ASCENDING)
    end

    it "handles the case of a field and a descending direction" do
      orders = Arel::Nodes::Ordering.new('table_name', 'field1 desc').orders
      expect(orders.size).to eq(1)
      expect(orders.first.field_name).to eq('field1')
      expect(orders.first.direction).to  eq(Arel::Nodes::Ordering::Order::DESCENDING)
    end

    it "handles the case of a two fields without directions" do
      orders = Arel::Nodes::Ordering.new('table_name', 'field2, field1').orders
      expect(orders.size).to eq(2)
      expect(orders.map{|order| order.field_name}).to eq(['field2', 'field1'])
      expect(orders.map{|order| order.direction}).to eq([Arel::Nodes::Ordering::Order::ASCENDING, Arel::Nodes::Ordering::Order::ASCENDING])
    end

    it "handles the case of a two fields with directions" do
      orders = Arel::Nodes::Ordering.new('table_name', 'field2 asc, field1 desc').orders
      expect(orders.size).to eq(2)
      expect(orders.map{|order| order.field_name}).to eq(['field2', 'field1'])
      expect(orders.map{|order| order.direction}).to eq([Arel::Nodes::Ordering::Order::ASCENDING, Arel::Nodes::Ordering::Order::DESCENDING])
    end

    it "raises an error on invalid order strings" do
      expect do
        orders = Arel::Nodes::Ordering.new('table_name', 'field1 abc').orders
      end.to raise_error(Exception)
    end
  end
end
