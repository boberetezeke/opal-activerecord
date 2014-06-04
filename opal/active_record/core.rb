class String
  def singularize
    /^(.*)s$/.match(self)[1]
  end

  def pluralize
    self + "s"
  end

  def camelize
    self.split(/_/).map{|word| word.capitalize}.join
  end

  def underscore
    if RUBY_ENGINE == 'opal'
      `#{self}.replace(/([A-Z\d]+)([A-Z][a-z])/g, '$1_$2')
      .replace(/([a-z\d])([A-Z])/g, '$1_$2')
      .replace(/-/g, '_')
      .toLowerCase()`
    else
      # stolen (mostly) from Rails::Activesupport
      return self unless self =~ /[A-Z-]|::/
      word = self.to_s.gsub('::', '/')
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end

  def blank?
    nil || self == ""
  end

  def present?
    !blank?
  end

  def presence
    self if present?
  end
end

$debug_on = false

def debug(str)
  puts(str) if $debug_on
end

module Arel
  class SelectManager
    attr_accessor :ordering, :limit, :offset
    attr_accessor :klass, :table_name, :node

    def initialize(connection, klass, table_name)
      @connection = connection
      @klass = klass
      @table_name = table_name
    end

    def where(node)
      @node = node
    end

    def execute
      @connection.execute(self)
    end

    def on_change(block, options={})
      @connection.on_change_with_select_manager(block, self, options)
    end
  end

  class Table
    def initialize(table_name)
      @table_name = table_name
    end

    def [](column_name)
      # FIXME: need to integrate table name into symbols
      Arel::Nodes::Symbol.new(column_name)
    end
  end

  module Nodes
    class Base
      def eq(node_or_value)
        Equality.new(self, convert_to_node(node_or_value))
      end

      def ne(node_or_value)
        NotEqual.new(self, convert_to_node(node_or_value))
      end

      def and(node_or_value)
        And.new(self, convert_to_node(node_or_value))
      end

      def or(node_or_value)
        Or.new(self, convert_to_node(node_or_value))
      end

      def convert_to_node(node_or_value)
        if node_or_value.is_a?(Base)
          return node_or_value
        else
          # assume it is a literal
          return Literal.new(node_or_value)
        end
      end
    end

    class BinaryOp < Base
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

    class Literal < Base
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

    class Symbol < Base
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
    attr_reader :foreign_key, :association_type, :name

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

    def klass
      Object.const_get(table_name.singularize.camelize)
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

    def where(*args)
      relation.where(*args)
    end

    def method_missing(sym, *args, &block)
      if [:first, :last, :all, :load, :reverse, :empty?].include?(sym)
        debug "CollectionProxy: method_missing: #{sym}"
        relation.send(sym, *args, &block)
      else
        super
      end
    end

    private

    def relation
        where_clause = "#{@owner.table_name.singularize}_id"
        debug "CollectionProxy: relation: for table: #{@association.table_name}, where: #{where_clause} == #{@owner.id}"
        Relation.new(@connection, @association.klass, @association.table_name).where(where_clause => @owner.id)
    end
  end

  class Relation
    def initialize(connection, klass, table_name)
      @select_manager = Arel::SelectManager.new(connection, klass, table_name)
    end

    def execute
      @records = @select_manager.execute
    end

    def where(query)
      if query.is_a?(Hash)
        key, value = query.first
        node = eq_node(key, value)
        if query.keys.size > 1
          query.to_a[1..-1].each do |key, value|
            node = Arel::Nodes::And.new(node, eq_node(key, value))
          end
        end
      else
        # FIXME: handle Arel nodes
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

    def includes(sym)
      # FIXME: implement includes if needed
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

    def empty?
      execute.empty?
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

    def on_change(block, options={})
      @select_manager.on_change(block, options)
      return self
    end
  end

  class AbstractStore
    class Observer < Struct.new(:call_back, :select_manager, :options); end

    def initialize(*args)
      @observers = []
    end

    def on_change(options={}, &call_back)
      @observers.push(Observer.new(call_back, nil, options))
    end

    def on_change_with_select_manager(call_back, select_manager, options={})
      @observers.push(Observer.new(call_back, select_manager, options)) 
    end

    def notify_observers(change, object, options={})
      debug "notify_observers: change = #{change}, object = #{object}, options = #{options}"
      @observers.each do |observer|
        debug "observer.options = #{observer.options}"
        next if options[:from_remote] &&     observer.options[:local_only]
        next if !(options[:from_remote]) &&  observer.options[:remote_only]
        debug "notifying observers!!"

        if observer.select_manager
          if record_matches(object, observer.select_manager)
            observer.call_back.call(change, object)
          end
        else
          observer.call_back.call(change, object)
        end
      end
    end

    def record_matches(record, select_manager)
      debug "LocalStorageStore#execute: node: #{select_manager.node}, checking record: #{record}"
      select_manager.node ?  select_manager.node.value(record) : true
    end
  end

  class LocalStorageStore < AbstractStore
    #
    # The index of array ids for a given table
    #
    class Index
      attr_reader :index

      def initialize(name, local_storage)
        @name = name
        @local_storage = local_storage
        @index = get
        if !@index
          @index = []
          put
        end
      end

      def insert(record_id)
        unless @index.include?(record_id)
          @index.push(record_id)
          put
        end
      end
        
      def delete(record_id)
        index.delete(record_id)
        put
      end

      private

      def local_storage_name
        "#{@name}:index"
      end

      def get
        @local_storage.get(local_storage_name)
      end

      def put
        @local_storage.set(local_storage_name, @index)
      end
    end

    #
    # This contains the index and next_id for a given table and
    # allows reading and writing of individual record attribute hashes
    #
    class Table
      attr_reader :next_id

      def initialize(name, local_storage)
        @local_storage = local_storage
        @name = name
        @index = Index.new(name, local_storage)
        @next_id = get_next_id
        if !@next_id
          @next_id = 1
          put_next_id
        end
      end

      def get_record_attributes(id)
        attributes = @local_storage.get(table_record_name(id))
        debug "LocalStorageStore::Table#get_record_attributes:#{id}:#{attributes}"
        attributes
      end

      def put_record_attributes(id, record_attributes)
        debug "LocalStorageStore::Table#put_record_attributes:#{id}:#{record_attributes}"
        @index.insert(id)
        @local_storage.set(table_record_name(id), record_attributes)
      end

      def get_all_record_attributes
        @index.index.map{|id| @local_storage.get(table_record_name(id))}
      end

      def delete_record_attributes(id)
        @local_storage.remove(table_record_name(id))
        @index.delete(id)
      end

      def generate_next_id
        @next_id += 1
        put_next_id
        @next_id
      end

      def get_next_id
        @local_storage.get(next_id_name)
      end 

      def put_next_id
        @local_storage.set(next_id_name, @next_id)
      end

      private

      def table_record_name(id)
        "#{@name}:#{id}"
      end

      def next_id_name
        "#{@name}:next_id"
      end
    end

    #
    # LocalStorageStore
    #
    # This stores record attributes (hashes) in local storage with one entry per record
    # In addition to storing the records it also stores an index of used ids and the 
    # next available id. The data is mapped to keys as follows
    #
    # table_name:# - a record is stored where # is the id of the record
    # table_name:next_id - holds the next id for the table
    # table_name:index - an array of record ids stored for that table
    #
    def initialize(browser_local_storage)
      super

      @local_storage = browser_local_storage
      @tables = {}
    end

    def execute(select_manager)
      table = get_table(select_manager.table_name)
      records = table.get_all_record_attributes.map do |attributes|
        select_manager.klass.new(attributes) 
      end.select do |record|
        record_matches(record, select_manager)
      end
      debug "LocalStorageStore#execute: result = #{records.inspect}"
      records
    end

    def push(table_name, record)
      table = get_table(table_name)
      table.put_record_attributes(record.id, record.attributes)
    end

    def find(klass, table_name, id)
      record_attributes = get_table(table_name).get_record_attributes(id)
      if record_attributes
        klass.new(record_attributes)
      else
        raise ActiveRecord::RecordNotFound.new("Record not found: class #{klass}, id #{id}")
      end
    end

    def create(klass, table_name, record, options={})
      debug "LocalStorageStore#create: #{table_name}, #{record}"
      table = get_table(table_name)
      next_id = table.generate_next_id
      record.attributes['id'] = next_id
      table.put_record_attributes(next_id, record.attributes)
      notify_observers(:insert, record, options)
      return next_id
    end

    def update(klass, table_name, record, options={})
      debug "LocalStorageStore#update: #{table_name}, #{record}"
      table = get_table(table_name)
      old_record_attributes = table.get_record_attributes(record.id)
      old_record_attributes = old_record_attributes.dup if old_record_attributes
      table.put_record_attributes(record.id, record.attributes)
      if old_record_attributes
        notify_observers(:update, record, options) if record.attributes != old_record_attributes 
      else
        notify_observers(:insert, record, options)
      end
      debug "LocalStorageStore#update: putting to #{record.id}, #{record.attributes}"
    end

    def update_id(klass, table_name, old_id, new_id)
      debug "LocalStorageStore#update_id: #{table_name}, #{old_id} to #{new_id}"
      
      table = get_table(table_name)
      record_attributes = table.get_record_attributes(old_id)
      table.delete_record_attributes(old_id)
      record_attributes['id'] = new_id
      table.put_record_attributes(new_id, record_attributes)
    end

    def destroy(klass, table_name, record, options={})
      notify_observers(:delete, record, options)
      table = get_table(table_name)
      table.delete_record_attributes(record.id)
    end


    def init_new_table(table_name)
      get_table(table_name)
    end

    def to_s
      @tables.each.map do |table_name, table|
        "#{table_name}::#{table.next_id}::#{table.get_all_record_attributes.inspect}"
      end.join(", ")
    end

    private

    def get_table(table_name)
      table = @tables[table_name] 
      return table if table
      @tables[table_name] = Table.new(table_name, @local_storage)
    end
  end

  class MemoryStore < AbstractStore
    attr_reader :tables

    def initialize
      super

      @tables = {}
      @next_ids = {}
    end

    def execute(select_manager)
      debug "MemoryStore#execute: table name = #{select_manager.table_name}"
      debug "MemoryStore#execute: tables = #{@tables.keys}"
      debug "MemoryStore#node = #{select_manager.node}"
      records = @tables[select_manager.table_name.to_s].values.select do |record|
        record_matches(record, select_manager)
      end
      debug "MemoryStore#execute: result = #{records.inspect}"
      records
    end

    def push(table_name, record)
      init_new_table(table_name)
      @tables[table_name][record.id] = record
    end

    def find(klass, table_name, id)
      if @tables[table_name]
        record = @tables[table_name][id]
      else
        record = nil
      end

      raise "record not found" unless record
      record
    end

    def create(klass, table_name, record, options)
      debug "MemoryStore#Create(#{record})"
      init_new_table(table_name)
      next_id = gen_next_id(table_name)
      @tables[table_name][next_id] = record
      notify_observers(:insert, record, options)
      return next_id
    end

    def update(klass, table_name, record, options={})
      init_new_table(table_name)
      table = @tables[table_name]
      old_attributes = table[record.id]
      if old_attributes
        notify_observers(:update, record, options) if record.attributes != table[record.id]
      end
      table[record.id] = record
    end

    def update_id(klass, table_name, old_id, new_id, options={})
      table = @tables[table_name]
      record = table.delete(old_id)
      record[:id] = new_id
      table[new_id] = record
    end

    def destroy(klass, table_name, record, options={})
      notify_observers(:delete, record, options)
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

  class Name
    attr_reader :singular, :plural, :element, :collection,
      :singular_route_key, :route_key, :param_key, :i18n_key,
      :name
    
    def initialize(klass)
      @singular = klass.to_s
      @singular = @singular[0..0].downcase + @singular[1..-1]
      @plural = @singular + "s"
      @param_key = @singular
    end
  end

  class RecordNotFound < Exception
  end

  class Base
    def self.new_objects_from_json(json, top_level_class=nil, options={})
      # if its a hash
      if /^\s*{/.match(json)
        return new_objects_from_hash(JSON.parse(json), top_level_class, options)
      elsif /^\s*\[/.match(json)
        return new_objects_from_array(JSON.parse(json), top_level_class, options)
      else
        raise "Unsupported JSON format (neither a hash or array)"
      end
    end

    def self.new_objects_from_hash(hash, top_level_class=nil, options={})
      [new_from_hash(hash, top_level_class, options)]
    end

    def self.new_objects_from_array(array, top_level_class=nil, options={})
      #puts "new_objects_from_array(#{top_level_class}): #{array}"
      array.map do |attributes|
        new_from_hash(attributes, top_level_class, options)
      end.flatten
    end

    def self.model_name
      Name.new(self)
    end

    def self.new_from_hash(hash, top_level_class=nil, options={})
      #puts "new_from_hash=#{hash}, top_level_class=#{top_level_class}"

      klass, hash = new_object_class(top_level_class, hash)
      object = klass.new

      #puts "klass = #{klass.inspect}"
      #puts "object = #{object.inspect}"
      #puts "hash keys = #{hash.keys}"
      #puts "association keys = #{klass.associations.keys}"

      association_keys = klass.associations.keys
      hash.each do |key, value|
        if association_keys.include?(key)
          association_class = klass.associations[key].klass
          if value.is_a?(Array)
            value = new_objects_from_array(value, association_class, options)
          else
            value = new_from_hash(value, association_class, options)
          end
        else
          #puts "#{key} not in association_keys = #{association_keys}"
        end

        object.write_value(key, value, options)
      end

=begin
      association_keys = hash.keys.map(&:to_s) & klass.associations.keys.map(&:to_s)
      association_keys.each do |key|
        attributes = hash.delete(key)
        if attributes.is_a?(Array)
          hash[key] = new_objects_from_array(attributes, klass.associations[key].klass)
        else
          hash[key] = new_from_hash(attributes)
        end
      end

      object.attributes = hash
=end

      #puts "Constructed Object: #{object}"
      return object
    end

    def self.new_object_class(top_level_class, hash)
      klass = top_level_class
      # attempt to extract the class name from the top level hash
      if !klass && hash.keys.size == 1
        class_name = hash.keys.first.to_s
        hash = hash.values.first

        # convert to uppercase name
        class_name = class_name.camelize
        klass = Object.const_get(class_name) 
      end

      klass = self unless klass

      return [klass, hash]
    end

    def self.accepts_nested_attributes_for(*args)
    end

    def self.default_scope(*args)
      # FIXME: Implement
    end

    def self.scope(*args)
      # FIXME: Implement
    end

    def self.has_many(name, options={})
      @associations ||= {}
      @associations[name.to_s] = Association.new(self, :has_many, name, options, @connection)
    end

    def self.belongs_to(name, options={})
      @associations ||= {}
      @associations[name.to_s] = Association.new(self, :belongs_to, name, options, @connection)
    end
    
    def self.arel_table
      Arel::Table.new(table_name)
    end

    def self.table_name
      self.to_s.underscore.pluralize
    end

    def self.find(id)
      connection.find(self, table_name, id)
    end

    #
    # create a relation on change call and return the relation
    #
    def self.on_change(options={}, &block)
      Relation.new(connection, self, table_name).on_change(block, options)
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
      if args.size > 1 && args.last.is_a?(Hash)
        options = args.pop
      else
        options = {}
      end

      obj = self.new(*args)
      obj.save(options)
      obj
    end

    def self.method_missing(sym, *args)
      if [:first, :last, :all, :where, :includes].include?(sym)
        Relation.new(connection, self, table_name).send(sym, *args)
      else
        super
      end
    end

    def self.new(*args)
      super(*args)
    end

    attr_accessor :attributes, :association_values, :observers

    def initialize(initializers={}, options={})
      @attributes = {}
      @association_values = {}
      @observers = {}
      initializers.each do |initializer, value|
        write_value(initializer.to_s, value, options)
      end
    end

    # FIXME: should we raise exception if attribute name is not association or defined column?
    #        currently don't keep track of valid columns per table
    def method_missing(sym, *args)
      method_name = sym.to_s
      debug "Base#method_missing: #{method_name}, #{attributes}"
      if m = /(.*)=$/.match(method_name) 
        if args.size == 1
          val = args.shift
          attribute_name = m[1]
          write_value(attribute_name, val)
          debug "Base#method_missing (at end), write #{attribute_name} = #{val}"
          return 
        end
      else 
        if args.size == 0
          val = read_value(method_name)
          debug "Base#method_missing (at end), val = #{val}"
          return val
        end
      end

      super
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

      if old_value != new_value
        if self.observers[attribute_name] then
          self.observers[attribute_name].each do |observer|
            observer.call(old_value, new_value)
          end
        end
      end
    end

    def read_attribute(attribute_name)
      self.attributes[attribute_name.to_s]
    end

    def write_association_value(assoc, values_or_value, options={})
      debug "write_association_value: #{assoc}, #{values_or_value}, options = #{options}"
      if assoc.association_type == :has_many
        if self.id
          values_or_value.each do |object|
            #if object.read_attribute(assoc.foreign_key) != self.id
              object.write_attribute(assoc.foreign_key, self.id)
              object.save(options)
            #end
          end
        else
          @association_values[assoc.name] = values_or_value
        end
      else
        @association_values[assoc.name] = values_or_value
      end
    end

    def read_association_value(assoc)
      debug "read_association_value: #{assoc}, #{@association_values}"
      if assoc.association_type == :has_many
        @association_values[assoc.name] || []
      else
        @association_values[assoc.name]
      end
    end

    def clear_association_value(assoc)
      @association_values.delete(assoc.name)
    end

    def write_value(name, new_value, options={})
      debug "write_value: name: #{name}, new_value: #{new_value}, options=#{options}"
      assoc = self.class.associations[name]
      if assoc 
        if self.id 
          if assoc.association_type == :has_many
            write_association_value(assoc, new_value, options)
          elsif assoc.association_type == :belongs_to
            #if new_value.id
            #  write_attribute(assoc.foreign_key, new_value.id)
            #else
              write_association_value(assoc, new_value, options)
            #end
          end
        else
          write_association_value(assoc, new_value, options)
        end
      else
        write_attribute(name, new_value)
      end
    end

    def read_value(name)
      debug "Base#read_value, name = #{name}, self.class.associations = #{self.class.associations.inspect}"
      assoc = self.class.associations[name]
      debug "Base#read_value: assoc = #{assoc}"
      if assoc = self.class.associations[name]
        val = (assoc.association_type == :has_many)
        if assoc.association_type == :has_many
          if self.id
            CollectionProxy.new(connection, self, assoc)
          else
            read_association_value(assoc)
          end
        elsif assoc.association_type == :belongs_to
          if read_attribute(assoc.foreign_key)
            debug "Base#read_value: belongs_to (id = #{self.id})"
            debug "Base#read_value: belongs_to: getting from relation: 'id' = #{read_attribute(assoc.foreign_key)}"
            Relation.new(connection, assoc.klass, assoc.table_name).where("id" => read_attribute(assoc.foreign_key)).first
          else
            debug "Base#read_value: belongs_to: reading from association_value"
            read_association_value(assoc)
          end
        end
      else
        read_attribute(name)
      end
    end

    def update(attributes, options={})
      attributes.each do |key, value|
        write_value(key, value)
      end
      self.save(options)
    end

    def destroy(options={})
      connection.destroy(self.class, table_name, self, options)
    end

    def save(options={})
      debug "save: memory(before) = #{connection}"
      debug "save: self(before): #{self}"
      self.class.associations.each do |name, assoc|
        value = read_association_value(assoc)
        debug "save: association(#{name}) value: #{value.inspect}"
        if value
          if assoc.association_type == :has_many
            value.each do |object|
              debug "save: has has_many_value: id(#{object.id}), #{object.attributes}"
              object.save(options)
            end
          else
            debug "save: has belongs_to_value: id(#{value.id}), #{value}"
            # FIXME: this should not be a forced save
            value.save(options) #unless value.id
            write_attribute(assoc.foreign_key, value.id)
          end
          clear_association_value(assoc)
        end
      end 

      debug "save: self(after): #{self}"
      if self.id
        connection.update(self.class, table_name, self, options)
      else
        @attributes['id'] = connection.create(self.class, table_name, self, options)
      end

      debug "save: memory(after) = #{connection.to_s}"
    end

    def update_id(new_id)
      connection.update_id(self.class, table_name, self.id, new_id)
    end

    def persisted?
      read_attribute(:id) != nil
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
      "#{self.class}: attributes: #{@attributes}, assoc_values: #{@association_values}"
    end
  end
end
