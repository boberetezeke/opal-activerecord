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

    def references(sym)
      # FIXME: implement references if needed
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

    def present?
      execute.present?
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
end
