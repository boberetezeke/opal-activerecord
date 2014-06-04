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

class MockLocalStorage
  attr_reader :storage
  def initialize
    @storage = {}
  end

  def set(name, value)
    if value.is_a?(Hash) || value.is_a?(Array)
      @storage[name] = value.dup
    else
      @storage[name] = value
    end
  end

  def get(name)
    @storage[name]
  end

  def remove(name)
    @storage.delete(name)
  end

  def to_s
    @storage.inspect
  end
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
    let(:mock_local_storage) { MockLocalStorage.new }
    let(:memory_store) { ActiveRecord::LocalStorageStore.new(mock_local_storage) }
    #let(:memory_store) { ActiveRecord::MemoryStore.new }
    before do
      ActiveRecord::Base.connection = memory_store
    end
  end

  if !running_with_real_active_record
    describe ".new_from_hash" do
      context "when constructing just one object" do
        context "when using a top level class" do
          it "should set attributes on a class with no relationships" do
            a = ActiveRecord::Base.new_from_hash({"x" => 1, "y" => 2}, A)
            expect(a.x).to eq(1)
            expect(a.y).to eq(2)
          end

          it "should set attributes on a class with a has_many relationship" do
            b = ActiveRecord::Base.new_from_hash({"x" => 1, "y" => 2}, B)
            expect(b.x).to eq(1)
            expect(b.y).to eq(2)
          end

          it "should set attributes on a class with a belongs_to relationship" do
            d = ActiveRecord::Base.new_from_hash({"x" => 1, "y" => 2}, D)
            expect(d.x).to eq(1)
            expect(d.y).to eq(2)
          end
        end

        context "when NOT using a root key" do
          it "should set attributes on a class with no relationships" do
            a = A.new_from_hash({"x" => 1, "y" => 2})
            expect(a.x).to eq(1)
            expect(a.y).to eq(2)
          end

          it "should set attributes on a class with a has_many relationship" do
            b = B.new_from_hash({"x" => 1, "y" => 2})
            expect(b.x).to eq(1)
            expect(b.y).to eq(2)
          end

          it "should set attributes on a class with a belongs_to relationship" do
            d = D.new_from_hash({"x" => 1, "y" => 2})
            expect(d.x).to eq(1)
            expect(d.y).to eq(2)
          end
        end

        context "when using a root key" do
          it "should set attributes on a class with no relationships" do
            a = A.new_from_hash({"a" => {"x" => 1, "y" => 2}})
            expect(a.x).to eq(1)
            expect(a.y).to eq(2)
          end

          it "should set attributes on a class with a has_many relationship" do
            b = B.new_from_hash({"b" => {"x" => 1, "y" => 2}})
            expect(b.x).to eq(1)
            expect(b.y).to eq(2)
          end

          it "should set attributes on a class with a belongs_to relationship" do
            d = D.new_from_hash({"d" => {"x" => 1, "y" => 2}})
            expect(d.x).to eq(1)
            expect(d.y).to eq(2)
          end
        end
      end

      context "when contructing an object with a has_many that contains embedded has_many objects" do
        context "when NOT using a root key" do
          it "should create the first object and the has_many objects" do
            b = B.new_from_hash({'x' => 1, 'y' => 2, 'cs' => [{'s' => 3, 't' => 4}]})
            expect(b.x).to eq(1)
            expect(b.y).to eq(2)
            expect(b.cs.size).to eq(1)
            expect(b.cs.first.s).to eq(3)
            expect(b.cs.first.t).to eq(4)
          end
        end

        context "when using a root key" do
          it "should create the first object and the has_many objects" do
            b = B.new_from_hash('b' => {'x' => 1, 'y' => 2, 'cs' => [{'s' => 3, 't' => 4}]})
            expect(b.x).to eq(1)
            expect(b.y).to eq(2)
            expect(b.cs.size).to eq(1)
            expect(b.cs.first.s).to eq(3)
            expect(b.cs.first.t).to eq(4)
          end
        end
      end

      context "when contructing an object with a has_many that contains embedded objects that also have many objects" do
        it "should create the first object and the has_many objects" do
          b = B.new_from_hash({'x' => 1, 'y' => 2, 'cs' => [{'s' => 3, 't' => 4, 'ds' => [{'m' => 5, 'n' => 6}]}]})
          expect(b.x).to eq(1)
          expect(b.y).to eq(2)
          expect(b.cs.size).to eq(1)
          expect(b.cs.first.s).to eq(3)
          expect(b.cs.first.t).to eq(4)
          expect(b.cs.first.ds.size).to eq(1)
          expect(b.cs.first.ds.first.m).to eq(5)
          expect(b.cs.first.ds.first.n).to eq(6)
        end
      end
    end

    describe ".new_objects_from_array" do
      context "when constructing objects from an array" do
        context "when NOT using a root key" do
          it "should set attributes on a class" do
            as = A.new_objects_from_array([{"x" => 1, "y" => 2}])
            expect(as.size).to eq(1)
            expect(as.first.x).to eq(1)
            expect(as.first.y).to eq(2)
          end
        end

        context "when using a root key" do
          it "should set attributes on a class" do
            as = A.new_objects_from_array([{"a" => {"x" => 1, "y" => 2}}])
            expect(as.size).to eq(1)
            expect(as.first.x).to eq(1)
            expect(as.first.y).to eq(2)
          end
        end
      end
    end

    describe ".new_objects_from_hash" do
      context "when constructing objects from a hash" do
        context "when NOT using a root key" do
          it "should set attributes on a class" do
            as = A.new_objects_from_hash({"x" => 1, "y" => 2})
            expect(as.size).to eq(1)
            expect(as.first.x).to eq(1)
            expect(as.first.y).to eq(2)
          end
        end

        context "when using a root key" do
          it "should set attributes on a class" do
            as = A.new_objects_from_hash({"a" => {"x" => 1, "y" => 2}})
            expect(as.size).to eq(1)
            expect(as.first.x).to eq(1)
            expect(as.first.y).to eq(2)
          end
        end
      end
    end

    describe ".new_objects_from_json" do
      context "when the top level object is a hash" do
        it "should set attributes on a class" do
          as = A.new_objects_from_json('{"x": 1, "y": 2}')
          expect(as.size).to eq(1)
          expect(as.first.x).to eq(1)
          expect(as.first.y).to eq(2)
        end

        it "should create the first object and the has_many objects" do
          bs = B.new_objects_from_json('{"b": {"x": 1, "y": 2, "cs": [{"s": 3, "t": 4}]}}')
          expect(bs.size).to eq(1)
          b = bs.first
          expect(b.x).to eq(1)
          expect(b.y).to eq(2)
          expect(b.cs.size).to eq(1)
          expect(b.cs.first.s).to eq(3)
          expect(b.cs.first.t).to eq(4)
        end
      end

      context "when the top level object is an array" do
        it "should set attributes on a class" do
          as = A.new_objects_from_json('[{"x": 1, "y": 2}]')
          expect(as.size).to eq(1)
          expect(as.first.x).to eq(1)
          expect(as.first.y).to eq(2)
        end
      end
    end

    context "when updating local id's with remote id's" do
      let(:a) { A.new(x:1) }

      before do
        a.save
      end

      it "should update the id in storage" do
        old_id = a.id
        new_id = old_id + 100

        a.update_id(new_id)

        expect{A.find(old_id)}.to raise_error(ActiveRecord::RecordNotFound)
        expect(A.find(new_id).id).to eq(new_id)
      end
      
    end

    context "when object observers are present" do
      let(:a) { A.new(x:1) }

      before do
        @changes = []
        a.on_change(:x) do |old_value, new_value|
          @changes.push([old_value, new_value])
        end
      end

      it "should update its observer when changes are made" do
        a.x = 2
        expect(@changes).to eq([[1, 2]])
      end

      it "should not update its observer if an update to an identical value is made" do
        a.x = 1
        expect(@changes).to eq([])
      end
    end

    context "when relation observers are present" do
      let!(:a1) { A.create(x:1) }
      let!(:a2) { A.create(x:2) }
      let!(:a3) { A.new(x:3) }

      context "updates are from a remote source and we want all changes" do
        before do
          @changes = []
          A.on_change do |action, object|
            @changes.push([action, object])
          end
        end

        it "should notify the observer when a new object is saved" do
          a3.save
          expect(@changes).to eq([[:insert, a3]])
        end

        it "should notify the observer when an object is modified" do
          a2.x = 4
          a2.save
          expect(@changes).to eq([[:update, a2]])
        end

        it "should notify the observer when an object is deleted" do
          a1.destroy
          expect(@changes).to eq([[:delete, a1]])
        end

        it "should notify the observer with changes to several objects" do
          a1.x = 10
          a1.save
          a2.update(x:20)
          a2.destroy
          a3.save
          expect(@changes).to eq([[:update, a1], [:update, a2], [:delete, a2], [:insert, a3]])
        end

        it "should notify the observer with changes on a create" do
          a = A.create(x: 1)
          expect(@changes).to eq([[:insert, a]])
        end
      end

      context "updates are from a remote source" do
        before do
          @changes = []
          A.on_change(local_only: true) do |action, object|
            @changes.push([action, object])
          end
        end

        it "shouldn't notify an observer if its an insert" do
          A.new(x:5).save(from_remote: true)
          expect(@changes).to eq([])
        end

        it "shouldn't notify an observer if its an update" do
          a1.x = 3
          a1.save(from_remote: true)
          expect(@changes).to eq([])
        end

        it "shouldn't notify an observer if its an update" do
          a1.update({x: 2}, from_remote: true)
          expect(@changes).to eq([])
        end

        it "shouldn't notify an observer if its a destroy" do
          a1.destroy(from_remote: true)
          expect(@changes).to eq([])
        end

        it "shouldn't notify the observer with changes on a create" do
          a = A.create({x: 1}, from_remote: true)
          expect(@changes).to eq([])
        end
      end
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
          #expect(memory_store.tables["as"].size).to eq(1)
          expect(mock_local_storage.get("as:index").size).to eq(1)
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
    let(:b)  { B.new(x:1) }
    let(:c)  { C.new(y:1) }
    let(:c2) { C.new(y:2) }
    let(:d)  { D.new(x:1, y:1) }

    context "when the objects are not yet saved" do

      it "has a B object with [] for the C association" do
        expect(b.cs).to eq([])
      end

      it "has a C object with nil for the B association" do
        expect(c.b).to be_nil
      end

      context "when writing to a has_many association" do
        context "when assigning an array of objects" do
          it "allows setting of C object on B" do
            b.cs = [c]
            expect(b.cs).to eq([c])
          end

          it "saves unsaved objects that are referenced in a has_many association" do
            b.cs = [c]
            b.save

            expect(c.id).to_not be_nil
          end

          it "doesn't save when assigning to a has_many association with all unsaved objects" do
            b.cs = [c, c2]

            expect(c.id).to be_nil
            expect(c2.id).to be_nil
          end

          it "saves when assigning to a has_many association with some saved objects" do
            b.save
            c.save
            b.cs = [c, c2]

            expect(c.id).to_not be_nil
            expect(C.find(c.id).b).to eq(b)
            expect(c.b).to eq(b)
            expect(c2.id).to_not be_nil
            expect(c2.b).to eq(b)
          end
        end
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

      context "when checking for b on unsaved c" do
        it "retrieves b" do
          c.b_id = b.id
          expect(c.b).to eq(b)
        end
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

  describe "#update" do
    it "updates and saves a new record" do
      A.new(x: 1, y: 2).update(x: 4)
      expect(A.first.x).to eq(4)
      expect(A.first.y).to eq(2)
    end

    it "updates a record on disk" do
      a = A.new(x: 1, y: 2)
      a.save
      a.update(x: 3)

      expect(A.first.x).to eq(3)
      expect(A.first.y).to eq(2)
    end
  end
end
 
