class String
  def singularize
    /^(.*)s$/.match(self)[1]
  end
end

def debug(str)
  #puts(str) #if $debug_on
end

module Arel
  class SelectManager
    attr_accessor :ordering, :limit, :offset
    attr_accessor :table_name, :node

    def initialize(connection, table_name)
      @connection = connection
      @table_name = table_name
    end

    def where(node)
      @node = node
    end

    def execute
      @connection.execute(self)
    end
  end

  module Nodes
    class BinaryOp
      attr_reader :left_node, :right_node
      def initialize(left_node, right_node)
        @left_node = left_node
        @right_node = right_node
      end

      def to_s
        "BinaryNode: #{self.class}: left:#{@left_node}, right:#{@right_node}"
      end
    end

    class And < BinaryOp
      def value(record)
        @left_node.value(record) && @right_node.value(record)
      end
    end

    class Or < BinaryOp
      def value(record)
        @left_node.value(record) || @right_node.value(record)
      end
    end

    class Equality < BinaryOp
      def value(record)
        @left_node.value(record) == @right_node.value(record)
      end
    end

    class NotEqual < BinaryOp
      def value(record)
        @left_node.value(record) != @right_node.value(record)
      end
    end

    class Literal
      def initialize(value)
        @value = value
      end

      def value(record)
        @value
      end

      def to_s
        "Literal: #{@value}"
      end
    end

    class Symbol
      def initialize(symbol)
        @symbol = symbol
      end

      def value(record)
        record.send(@symbol)
      end

      def to_s
        "Symbol: #{@symbol}"
      end
    end

    class Ordering
      attr_reader :order_str
      def initialize(order_str)
        @order_str = order_str
      end
    end

    class Limit
      attr_reader :limit
      def initialize(limit)
        @limit = limit
      end
    end
  end
end

module ActiveRecord
  class Association
    attr_reader :foreign_key, :association_type

    def initialize(klass, association_type, name, options, connection)
      @association_type = association_type
      @klass = klass
      @name = name
      @options = options
      @connection = connection
      if @association_type == :belongs_to
        @foreign_key =  "#{name}_id"
      elsif @association_type == :has_many
        @foreign_key = "#{@klass.table_name.singularize}_id"
      end
    end

    def table_name
      (@association_type == :belongs_to) ? @name.to_s + "s" : @name.to_s
    end

    def all
      where(1 => 1)
    end
    alias load all

    def where(query={})
      Relation.new(query, @connection) 
    end

    def to_s
      "#Association: #{@name}: #{@association_type}"
    end
  end

  class CollectionProxy
    def initialize(connection, owner, association)
      @connection = connection
      @owner = owner
      @association = association
    end

    def <<(collection)
      debug "CollectionProxy(owner: #{@owner})#<<(#{collection})"
      collection = [collection] unless collection.is_a?(Array)
      collection.each do |obj|
        obj.write_attribute(@association.foreign_key, @owner.id)
        obj.save
      end
    end

    def method_missing(sym, *args, &block)
      if [:first, :last, :all, :load, :reverse].include?(sym)
        where_clause = "#{@owner.table_name.singularize}_id"
        debug "#{sym}: for table: #{@association.table_name}, where: #{where_clause} == #{@owner.id}"
        Relation.new(@connection, @association.table_name).where(where_clause => @owner.id).send(sym)
      else
        super
      end
    end
  end

  class Relation
    def initialize(connection, table_name)
      @select_manager = Arel::SelectManager.new(connection, table_name)
    end

    def execute
      @records = @select_manager.execute
    end

    def where(query)
      key, value = query.first
      node = eq_node(key, value)
      if query.keys.size > 1
        query.to_a[1..-1].each do |key, value|
          node = Arel::Nodes::And.new(node, eq_node(key, value))
        end
      end

      @select_manager.where(node)
      self
    end

    def order(order_str)
      @select_manager.ordering = Arel::Nodes::Ordering.new(order_str)
      self
    end

    def limit(num)
      @select_manager.limit = Arel::Nodes::Limit.new(num)
      self
    end

    def offset(index)
      @select_manager.offset = Arel::Nodes::Offset.new(index)
      self
    end

    def first
      execute.first
    end

    def last
      execute.last
    end

    def reverse
      execute.reverse
    end

    def [](index)
      execute[index]
    end

    def all
      execute
    end
    alias load all

    def each
      execute.each { |record| yield record }
    end

    def eq_node(key, value)
      Arel::Nodes::Equality.new(Arel::Nodes::Symbol.new(key), Arel::Nodes::Literal.new(value))
    end
  end

  class MemoryStore
    attr_reader :tables

    def initialize
      @tables = {}
      @next_ids = {}
    end

    def execute(select_manager)
      debug "MemoryStore#execute: table name = #{select_manager.table_name}"
      debug "MemoryStore#execute: tables = #{@tables.keys}"
      debug "MemoryStore#node = #{select_manager.node}"
      records = @tables[select_manager.table_name.to_s].values.select do |record|
        if select_manager.node
          debug "MemoryStore#execute: checking record: #{record}"
          select_manager.node.value(record)
        else
          true
        end
      end
      debug "MemoryStore#execute: result = #{records.inspect}"
      records
    end

    def push(table_name, record)
      init_new_table(table_name)
      @tables[table_name][record.id] = record
    end

    def find(table_name, id)
      if @tables[table_name]
        record = @tables[table_name][id]
      else
        record = nil
      end

      raise "record not found" unless record
      record
    end

    def on_change(&call_back)
      @change_callback = call_back
    end

    def create(table_name, record)
      debug "MemoryStore#Create(#{record})"
      init_new_table(table_name)
      next_id = gen_next_id(table_name)
      @tables[table_name][next_id] = record
      @change_callback.call(:insert, record) if @change_callback
      return next_id
    end

    def update(table_name, record)
      init_new_table(table_name)
      table = @tables[table_name]
      @change_callback.call(:update, record) if @change_callback && record.attributes != table[record.id]
      table[record.id] = record
    end

    def destroy(table_name, record)
      @change_callback.call(:delete, record) if @change_callback
      @tables[table_name].delete(record.id)
    end

    def gen_next_id(table_name)
      next_id = @next_ids[table_name]
      @next_ids[table_name] += 1
      return "T-#{next_id}"
    end

    def init_new_table(table_name)
      @tables[table_name] ||= {}
      @next_ids[table_name] ||= 1
    end

    def to_s
      "tables: #{@tables.inspect}, next_ids: #{@next_ids.inspect}"
    end
  end

  class Base
    attr_accessor :attributes, :observers

    def self.new_from_json(json)
      object = self.new
      object.attributes = json
      object
    end

    def self.accepts_nested_attributes_for(*args)
    end

    def self.default_scope(*args)
    end

    def self.scope(*args)
    end

    def self.has_many(name, options={})
      @associations ||= {}
      @associations[name.to_s] = Association.new(self, :has_many, name, options, @connection)
    end

    def self.belongs_to(name, options={})
      @associations ||= {}
      @associations[name.to_s] = Association.new(self, :belongs_to, name, options, @connection)
    end
    
    def self.table_name
      self.to_s.downcase + "s"
    end

    def self.find(id)
      connection.find(table_name, id)
    end

    def self.associations
      @associations || {}
    end

    def self.after_initialize(sym)
      @after_initialize_callback = sym
    end

    def self.connection
      # FIXME: Base.connection seems very hacky, ideally I would like
      #        to do something like super.respond_to?(:connection)
      #
      @connection || Base.connection
    end

    def self.connection=(connection)
      @connection = connection
    end

    def self.create(*args)
      obj = self.new(*args)
      #obj.save
      obj
    end

    def self.method_missing(sym, *args)
      if [:first, :last, :all, :where].include?(sym)
        Relation.new(connection, table_name).send(sym, *args)
      else
        super
      end
    end

    def self.new(*args)
      super(*args)
    end

    def initialize(initializers={})
      @attributes = {}
      @associations = {}
      @observers = {}
      initializers.each do |initializer, value|
        @attributes[initializer.to_s] = value
      end
    end

    def method_missing(sym, *args)
      method_name = sym.to_s
      debug "Base#method_missing: #{method_name}, #{attributes}"
      if m = /(.*)=$/.match(method_name)
        val = write_value(m[1], args.shift)
      else
        val = read_value(method_name)
      end
      debug "Base#method_missing (at end), val = #{val}"
      val
    end

    # stolen from ActiveRecord:core.rb
    def ==(comparison_object)
       super ||
       comparison_object.instance_of?(self.class) &&
         !id.nil? &&
        comparison_object.id == id
    end
    alias :eql? :==

    def on_change(sym, &block)
      str = sym.to_s
      self.observers ||= {}
      self.observers[str] ||= []
      self.observers[str].push(block)
      debug "Base#on_change: self.observers = #{self.observers.inspect}"
    end

    def write_attribute(attribute_name, new_value)
      attribute_name = attribute_name.to_s
      old_value = self.attributes[attribute_name]
      self.attributes[attribute_name] = new_value

      if self.observers[attribute_name] then
        self.observers[attribute_name].each do |observer|
          observer.call(old_value, new_value)
        end
      end
    end

    def read_attribute(attribute_name)
      self.attributes[attribute_name.to_s]
    end

    def write_value(name, new_value)
      assoc = self.class.associations[name]
      if assoc 
        if self.id 
          if assoc.association_type == :has_many
            new_value.each do |value|
              value.write_attribute("#{table_name.singularize}_id", self.id)
              value.save
            end
          elsif assoc.association_type == :belongs_to
            if new_value.id
              write_attribute("#{new_value.table_name}_id", new_value.id)

            else
              write_attribute(name, new_value)
            end
          end
        else
          write_attribute(name, new_value)
        end
      else
        write_attribute(name, new_value)
      end
    end

    def read_value(name)
      debug "Base#read_value, name = #{name}, self.class.associations = #{self.class.associations.inspect}"
      if assoc = self.class.associations[name]
        val = (assoc.association_type == :has_many)
        if assoc.association_type == :has_many
          if self.id
            CollectionProxy.new(connection, self, assoc)
          else
            read_attribute(name) || []
          end
        elsif assoc.association_type == :belongs_to
          if self.id
            Relation.new(connection, assoc.table_name).where("id" => read_attribute("#{assoc.table_name}_id")).first
          else
            read_attribute(name)
          end
        end
      else
        read_attribute(name)
      end
    end

    def save
      debug "save: memory(before) = #{connection}"
      debug "save: self(before): #{self}"
      self.class.associations.to_a.select do |name_and_assoc|
        name = name_and_assoc[0]
        assoc = name_and_assoc[1]
        assoc.association_type == :belongs_to
      end.each do |name_and_assoc|
        name = name_and_assoc[0]
        assoc = name_and_assoc[1]
        debug "name = #{name}, #{assoc}"
        debug "value = #{read_attribute(name).inspect}"
        belongs_to_value =  read_attribute(name)
        if belongs_to_value 
          debug "save: has belongs_to_value: id(#{belongs_to_value.id}), #{belongs_to_value.attributes}"
          belongs_to_value.save unless belongs_to_value.id
          @attributes["#{name}_id"] = belongs_to_value.id
        end
      end 

      debug "save: self(after): #{self}"
      if self.id
        connection.update(table_name, self)
      else
        @attributes['id'] = connection.create(table_name, self)
      end

      debug "save: memory(after) = #{connection}"
    end

    def destroy
      @connection.destroy(table_name, self)
    end

    def id
      @attributes['id']
    end

    def table_name
      self.class.table_name
    end

    def connection
      self.class.connection
    end

    def to_s
      "#{self.class}:#{self.attributes}"
    end
  end
end
