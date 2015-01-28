require 'spec_helper'

describe ActiveRecord::AbstractStore do
  describe "#join_tables" do
    let(:abstract_store) { ActiveRecord::AbstractStore.new }
    context "simple join" do
      it "should join all rows" do
        table1 = [
            {"table1" => {id: 1, name: 'first'}},
            {"table1" => {id: 2, name: 'second'}}
        ]
        table2 = [
            {"table2" => {id: 1, table1_id: 1}},
            {"table2" => {id: 2, table1_id: 1}},
            {"table2" => {id: 3, table1_id: 2}}
        ]

        expect(abstract_store.join_tables(table1, table2, "table1", :id, "table2", :table1_id)).to eq(
           [
               {"table1" => {id: 1, name: 'first'},  "table2" => {id: 1, table1_id: 1}},
               {"table1" => {id: 1, name: 'first'},  "table2" => {id: 2, table1_id: 1}},
               {"table1" => {id: 2, name: 'second'}, "table2" => {id: 3, table1_id: 2}}
           ])
      end

      it "skips non-matching rows" do
        table1 = [
            {"table1" => {id: 1, name: 'first'}},
            {"table1" => {id: 2, name: 'second'}},
            {"table1" => {id: 3, name: 'third'}}
        ]
        table2 = [
            {"table2" => {id: 1, table1_id: 1}},
            {"table2" => {id: 2, table1_id: 1}},
            {"table2" => {id: 3, table1_id: 3}}
        ]

        expect(abstract_store.join_tables(table1, table2, "table1", :id, "table2", :table1_id)).to eq(
           [
               {"table1" => {id: 1, name: 'first'}, "table2" => {id: 1, table1_id: 1}},
               {"table1" => {id: 1, name: 'first'}, "table2" => {id: 2, table1_id: 1}},
               {"table1" => {id: 3, name: 'third'}, "table2" => {id: 3, table1_id: 3}}
           ])
      end

      it "returns an empty table if no matches" do
        table1 = [
            {"table1" => {id: 1, name: 'first'}},
            {"table1" => {id: 2, name: 'second'}}
        ]
        table2 = [
            {"table2" => {id: 1, table1_id: 3}},
            {"table2" => {id: 2, table1_id: 4}}
        ]

        expect(abstract_store.join_tables(table1, table2, "table1", :id, "table2", :table1_id)).to eq([])
      end

      it "joins previously joined tables" do
        table1 = [
            {"table1" => {id: 5, name: 'first'},  "table2" => {id: 1, table1_id: 1}},
            {"table1" => {id: 6, name: 'second'}, "table2" => {id: 2, table1_id: 2}}
        ]
        table3 = [
            {"table3" => {id: 1, table2_id: 1}},
            {"table3" => {id: 2, table2_id: 2}}
        ]

        expect(abstract_store.join_tables(table1, table3, "table2", :id, "table3", :table2_id)).to eq([
            {"table1" => {id: 5, name: 'first'},  "table2" => {id: 1, table1_id: 1}, "table3" => {id: 1, table2_id: 1}},
            {"table1" => {id: 6, name: 'second'}, "table2" => {id: 2, table1_id: 2}, "table3" => {id: 2, table2_id: 2}}
        ])
      end

      it "joins previously joined tables with duplicated left keys" do
        table1 = [
            {"table1" => {id: 1, name: 'first'},  "table2" => {id: 1, table1_id: 1, table3_id: 1}},
            {"table1" => {id: 2, name: 'second'}, "table2" => {id: 2, table1_id: 2, table3_id: 1}},
            {"table1" => {id: 2, name: 'second'}, "table2" => {id: 2, table1_id: 2, table3_id: 2}}
        ]
        table3 = [
            {"table3" => {id: 1}},
            {"table3" => {id: 2}}
        ]

        expect(abstract_store.join_tables(table1, table3, "table2", :table3_id, "table3", :id)).to eq([
            {"table1" => {id: 1, name: 'first'},  "table2" => {id: 1, table1_id: 1, table3_id: 1}, "table3" => {id: 1}},
            {"table1" => {id: 2, name: 'second'}, "table2" => {id: 2, table1_id: 2, table3_id: 1}, "table3" => {id: 1}},
            {"table1" => {id: 2, name: 'second'}, "table2" => {id: 2, table1_id: 2, table3_id: 2}, "table3" => {id: 2}}
        ])
      end
    end
  end
end