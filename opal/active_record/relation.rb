module ActiveRecord
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
        node = query
      end

      @select_manager.where(node)
      self
    end

    def order(order_str)
      @select_manager.ordering = Arel::Nodes::Ordering.new(@select_manager.table_name, order_str)
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

    def joins(join_spec)
      if join_spec.is_a?(Hash)
        association_join_spec = {}
        join_spec.each do |from_association_name, to_association_name|
          from_association = @select_manager.klass.associations[from_association_name.to_s]
          raise "single level hashes only allowed" unless to_association_name.is_a?(Symbol) || to_association_name.is_a?(String)

          to_association = from_association.klass.associations[to_association_name.to_s]
          association_join_spec[from_association] = to_association
        end
      else
        association_join_spec = { @select_manager.klass.associations[join_spec.to_s] => nil }
      end
      @select_manager.joins.push(Arel::Nodes::Join.new(association_join_spec))
      self
    end

    def includes(sym)
      # FIXME: implement includes if needed
      self
    end

    def references(sym)
      # FIXME: implement references if needed
      self
    end

    def method_missing(sym, *args, &block)
      if LAZY_METHODS.include?(sym)
        execute.send(sym, *args, &block)
      end
    end

    def present?
      execute.present?
    end

    def empty?
      execute.empty?
    end

    def all
      execute
    end
    alias load all

    def eq_node(key, value)
      Arel::Nodes::Equality.new(Arel::Nodes::Symbol.new(@select_manager.table_name, key), Arel::Nodes::Literal.new(value))
    end

    def on_change(block, options={})
      @select_manager.on_change(block, options)
      return self
    end
  end
end
