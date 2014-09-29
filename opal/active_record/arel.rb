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
