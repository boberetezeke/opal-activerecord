require 'spec_helper'

class A < ActiveRecord::Base
end

class B < ActiveRecord::Base
  has_many :cs
end

class C < ActiveRecord::Base
  belongs_to :b
  has_many :ds
end

class D < ActiveRecord::Base
  belongs_to :c
  belongs_to :e
end

class E < ActiveRecord::Base
  has_many :ds
  has_many :cs, :through => :ds
end

describe "ActiveRecord::Base" do
  if running_with_real_active_record
    before do
      ActiveRecord::Base.establish_connection(
        adapter:  'sqlite3',
        database: 'test.sqlite3'
      )
      ActiveRecord::Base.connection.create_table("as") {|t| t.integer :x; t.integer :y}
      ActiveRecord::Base.connection.create_table("bs") {|t| t.integer :x; t.integer :y}
      ActiveRecord::Base.connection.create_table("cs") {|t| t.integer :x; t.integer :y; t.integer :b_id}
      ActiveRecord::Base.connection.create_table("ds") {|t| t.integer :x; t.integer :y; t.integer :c_id; t.integer :e_id}
      ActiveRecord::Base.connection.create_table("es") {|t| t.integer :x; t.integer :y}
    end

    after do
      ActiveRecord::Base.connection.drop_table("as")
      ActiveRecord::Base.connection.drop_table("bs")
      ActiveRecord::Base.connection.drop_table("cs")
      ActiveRecord::Base.connection.drop_table("ds")
      ActiveRecord::Base.connection.drop_table("es")
    end
  else
    # only set memory_store for opal
    let(:memory_store) { ActiveRecord::MemoryStore.new }
    before do
      ActiveRecord::Base.connection = memory_store
    end
  end

  if !running_with_real_active_record
    describe ".new_from_json" do
      context "when constructing just one object" do
        it "should set attributes on a class with no relationships" do
          a = A.new_from_json({"x" => 1, "y" => 2})
          expect(a.x).to eq(1)
          expect(a.y).to eq(2)
        end

        it "should set attributes on a class with a has_many relationship" do
          b = B.new_from_json({"x" => 1, "y" => 2})
          expect(b.x).to eq(1)
          expect(b.y).to eq(2)
        end

        it "should set attributes on a class with a belongs_to relationship" do
          d = D.new_from_json({"x" => 1, "y" => 2})
          expect(d.x).to eq(1)
          expect(d.y).to eq(2)
        end
      end

=begin
      context "when contructing an object with a has_many that contains embedded has_many objects" do
        it "should create the first object and the has_many objects" do
          b = B.new_from_json({x: 1, y: 2, cs: [{s: 3, t: 4}]})
          expect(b.x).to eq(1)
          expect(b.y).to eq(2)
          expect(b.c.size).to eq(1)
          #expect(b.c.first.s).to eq(3)
          #expect(b.c.first.t).to eq(4)
        end
      end
=end
    end
  end

  context "when using an active record model with no associations" do
    it "should be true" do
      expect(nil).to eq(nil)
    end
  end

  context "when using an active record model with no associations" do

    context "when starting with a new model" do
      let(:a) { A.new(x:1) }

      context "when testing for equality" do
        let(:a1) { A.new(x:1, y:1) }
        let(:a2) { A.new(x:1, y:1) }

        it "is equal if the objects are the same object" do
          expect(a1 == a1).to eq(true)
        end

        it "is not equal if the objects are different objects" do
          expect(a1 == a2).to eq(false)
        end
      end

      it "can create one" do
        expect(a.x).to eq(1)
      end

      it "has no id" do
        expect(a.id).to be_nil
      end

      it "has an id after save" do
        a.save
        expect(a.id).to_not be_nil
      end

      if !running_with_real_active_record
        it "is in the store after the save" do
          a.save
          expect(memory_store.tables["as"].size).to eq(1)
        end
      end

    end

    context "when searching for objects" do
      let(:a1) { A.new(x:1, y:1) }
      let(:a2) { A.new(x:1, y:2) }
      let(:a3) { A.new(x:2, y:2) }

      before do
        a1.save
        a2.save
        a3.save
      end

      context "when testing for equality" do
        it "is equal if the objects have the same id" do
          expect(a1 == A.first).to eq(true)
        end

        it "is not equal if the objects are different objects" do
          expect(a2 == A.first).to eq(false)
        end
      end

      it "finds the first object saved when using first" do
        expect(A.first.x).to eq(1)
      end

      it "finds the last object saved when using last" do
        expect(A.last.x).to eq(2)
      end

      it "returns all records when using load" do
        expect(A.all.map{|a| a.x}.sort).to eq([1,1,2])
      end

      it "returns the record with 1 when using where" do
        expect(A.where(x:1,y:1).load.map{|a| [a.x,a.y]}).to eq([[1,1]])
      end

      it "returns the record with x:1 and y:3 when using where" do
        expect(A.where(x:1).load.map{|a| a.y}).to eq([1,2])
      end
    end
  end

  context "when using an active record models with has_many/belongs_to associations" do
    let(:b) { B.new(x:1) }
    let(:c) { C.new(y:1) }
    let(:d) { D.new(x:1, y:1) }

    context "when the objects are not yet saved" do

      it "has a B object with [] for the C association" do
        expect(b.cs).to eq([])
      end

      it "has a C object with nil for the B association" do
        expect(c.b).to be_nil
      end

      it "allows setting of C object on B" do
        b.cs = [c]
        expect(b.cs).to eq([c])
      end

      it "allows setting of B object on C" do
        c.b = b
        expect(c.b).to eq(b)
      end

      it "saves b when saving c" do
        c.b = b
        c.save
        expect(b.id).to_not be_nil
      end

      it "saves b and c when saving d" do
        c.b = b
        d.c = c
        d.save
        expect(c.id).to_not be_nil
        expect(b.id).to_not be_nil
      end
    end

    context "when the has many side is saved only" do
      before do
        b.save
      end

      context "when setting cs" do
        it "allows setting of C object on B" do
          b.cs = [c]
          expect(b.cs.load).to eq([c])
        end

        it "saves C object when associating it with B" do
          b.cs = [c]
          expect(c.id).to_not be_nil
        end
      end

      context "when appending to cs" do
        it "allows setting of C object on B" do
          b.cs << c
          expect(b.cs.load).to eq([c])
        end

        it "saves C object when associating it with B" do
          b.cs  << c
          expect(c.id).to_not be_nil
        end
      end
    end

    context "when the belongs_to side is saved only" do
      before do
        c.save
      end

      context "when setting b" do

        it "doesn't save b on assignment to c" do
          c.b = b
          expect(b.id).to be_nil
        end

        it "saves b when saving c" do
          c.b = b
          c.save
          expect(b.id).to_not be_nil
        end
      end
    end

    context "when objects are saved" do
      before do
        b.save
        c.save
      end

      it "has a B object with [] for the C association" do
        expect(b.cs.load).to eq([])
      end

      it "has a C object with nil for the B association" do
        expect(c.b).to be_nil
      end

      it "allows setting of C object on B" do
        b.cs = [c]
        expect(b.cs.load).to eq([c])
      end

      it "allows setting of B object on C" do
        c.b = b
        c.save
        expect(c.b).to eq(b)
      end
    end
  end
end
 
