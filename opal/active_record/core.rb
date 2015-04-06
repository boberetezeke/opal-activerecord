$debug_on = false
require 'json'

def debug(str)
  puts(str) if $debug_on
end

module ActiveRecord
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
    include ActiveRecord::Callbacks::InstanceMethods
    extend ActiveRecord::Callbacks::ClassMethods

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
      debug "new_objects_from_array: array size #{array.size}"
      debug "new_objects_from_array(#{top_level_class}): #{array}"
      array.map do |attributes|
        debug "attributes=#{attributes}"
        new_from_hash(attributes, top_level_class, options)
      end.flatten
    end

    def self.model_name
      Name.new(self)
    end

    def self.new_from_hash(hash, top_level_class=nil, options={})
      debug "new_from_hash=#{hash}, top_level_class=#{top_level_class}"

      klass, hash = new_object_class(top_level_class, hash)
      object = klass.new

      debug "klass = #{klass.inspect}"
      debug "object = #{object.inspect}"
      debug "hash keys = #{hash.keys}"
      debug "association keys = #{klass.associations.keys}"

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
          debug "#{key} not in association_keys = #{association_keys}"
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

      debug "Constructed Object: #{object}"
      return object
    end

    def self.new_object_class(top_level_class, hash)
      debug "new_object_class, hash.keys: #{hash.size}"
      klass = top_level_class
      # attempt to extract the class name from the top level hash
      if !klass && hash.keys.size == 1
        class_name = hash.keys.first.to_s
        hash = hash.values.first
        debug "class_name = #{class_name}"
        debug "hash = #{hash}"

        # convert to uppercase name
        class_name = class_name.camelize
        klass = Object.const_get(class_name)
      end

      klass = self unless klass

      return [klass, hash]
    end

    def self.accepts_nested_attributes_for(*args)
    end

    # stubs for validation routines
    def self.validates_presence_of(*args); end
    def self.validates!(*args); end
    def self.validates_each(*args); end
    def self.validates_with(*args); end
    def self.validates_size_of(*args); end
    def self.validates_format_of(*args); end
    def self.validates_length_of(*args); end
    def self.validates_absence_of(*args); end
    def self.validates_associated(*args); end
    def self.validates_exclusion_of(*args); end
    def self.validates_inclusion_of(*args); end
    def self.validates_acceptance_of(*args); end
    def self.validates_uniqueness_of(*args); end
    def self.validates_confirmation_of(*args); end
    def self.validates_numericality_of(*args); end
    def self.validate(*args); end

    def self.default_scope(*args)
      if args.size == 1 && args.first.is_a?(Proc)
        @default_scope = args.first
      end
    end

    def self.scope(*args)
      @scopes ||= {}

      if args.size == 2 && args[0].is_a?(Symbol) && args[1].is_a?(Proc)
        scope_name, method_body  = args
        @scopes[scope_name] = method_body
        self.scopes
      else
        raise "scope requires name and lambda as arguments"
      end
    end

    def self.scopes
      @scopes || {}
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
      if [:first, :last, :all, :where, :includes, :order].include?(sym)
        Relation.new(connection, self, table_name).send(sym, *args)
      elsif m = /^(after|before|around)_(.*)/.match(sym.to_s)
        self.add_callback(m[1], m[2], args)
      elsif @scopes && @scopes[sym]
        @scopes[sym].call
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
          debug "Base#read_value: belongs_to: assoc.foreign_key: #{assoc.foreign_key}"
          if read_attribute(assoc.foreign_key)
            debug "Base#read_value: belongs_to (id = #{self.id})"
            debug "Base#read_value: belongs_to: getting from relation: 'id' = #{read_attribute(assoc.foreign_key)}"
            debug "Base#read_value: Relation.new(connection, #{assoc.klass}, #{assoc.table_name}).where('id' => #{read_attribute(assoc.foreign_key).inspect})"
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
      callbackable(:save) do
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
