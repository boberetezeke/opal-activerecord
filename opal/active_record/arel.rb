module Arel
  class SelectManager
    attr_accessor :ordering, :limit, :offset, :joins
    attr_accessor :klass, :table_name, :node

    def initialize(connection, klass, table_name)
      @connection = connection
      @klass = klass
      @table_name = table_name
      @joins = []
    end

    def where(node)
      debug "SelectManager#where: node: #{node}, existing @node = #{@node}"
      # if there is a node already, just and it in
      if @node
        @node =  Arel::Nodes::And.new(node, @node)
      else
        @node = node
      end
    end

    def execute
      @connection.execute(self)
    end

   def filter(records)
      records = select(records)
      records = ordering.execute(records) if ordering
      records = offset.offset(records) if offset
      records = limit.limit(records)   if limit
      records
    end

    def select(records)
      records.select {|record| record_matches(record) }
    end

    def record_matches(record)
      if node
        #puts("SelectManager#record_matches: match with #{node}")
      else
        #puts("SelectManager#record_matches: match with nil node")
      end

      result = !node || node.value(record)

      if node
        #puts("SelectManager#record_matches: #{result} = #{record}")
      else
        #puts("SelectManager#record_matches: #{result} = nil node")
      end

      result
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
      Arel::Nodes::Symbol.new(@table_name, column_name)
    end
  end

  module Nodes
    class Base
      def eq(node_or_value)
        Equality.new(self, convert_to_node(node_or_value))
      end

      def not_eq(node_or_value)
        NotEqual.new(self, convert_to_node(node_or_value))
      end

      def and(node_or_value)
        And.new(self, convert_to_node(node_or_value))
      end

      def or(node_or_value)
        Or.new(self, convert_to_node(node_or_value))
      end

      def in(node_or_value)
        In.new(self, convert_to_node(node_or_value))
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

      def to_s
        "#{@left_node} && #{@right_node}"
      end
    end

    class Or < BinaryOp
      def value(record)
        @left_node.value(record) || @right_node.value(record)
      end

      def to_s
        "#{@left_node} || #{@right_node}"
      end
    end

    class In < BinaryOp
      def value(record)
        @right_node.value(record).include?(@left_node.value(record))
      end

      def to_s
        "#{@left_node} in #{@right_node}"
      end
    end

    class Equality < BinaryOp
      def value(record)
        @left_node.value(record) == @right_node.value(record)
      end

      def to_s
        "#{@left_node} == #{@right_node}"
      end
    end

    class NotEqual < BinaryOp
      def value(record)
        @left_node.value(record) != @right_node.value(record)
      end

      def to_s
        "#{@left_node} != #{@right_node}"
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
      def initialize(table_name, symbol)
        @table_name = table_name
        @symbol = symbol
      end

      def value(record)
        record[@table_name][@symbol.to_s]
      end

      def asc
        @direction = :asc
      end

      def desc
        @direction = :desc
      end

      def to_s
        "Symbol: #{@table_name}::#{@symbol}"
      end
    end

    class Ordering
      attr_reader :table_name, :order_str, :orders
      def initialize(table_name, order_str)
        @order_str = order_str
        @table_name = table_name
        @orders = @order_str.split(/,/).map{|order| order.strip}.map{|str| Order.new(table_name, str)}
      end

      def execute(records)
        records.sort do |record1, record2|
          val1 = val2 = nil
          non_matching_order = nil
          @orders.each do |order|
            non_matching_order = order
            val1 = record1[order.table_name][order.field_name.to_s]
            val2 = record2[order.table_name][order.field_name.to_s]

            break if val1 != val2
          end

          # sort nils to end
          if val1.nil? && !val2.nil?
            1
          elsif val2.nil? && !val1.nil?
            -1
          else
            # they either are both nil or both not nil
            if non_matching_order.descending?
              val2 <=> val1
            else
              val1 <=> val2
            end
          end
        end
      end

      class Order
        ASCENDING = :ascending
        DESCENDING = :descending

        attr_reader :table_name, :field_name, :direction
        def initialize(table_name, str)
          m = /^(\w+)(\s+(asc|desc|ASC|DESC))?$/.match(str)
          if m
            @table_name = table_name
            @field_name = m[1]
            if m[2]
              if m[3] == 'asc' || m[3] == 'ASC'
                @direction = ASCENDING
              else
                @direction = DESCENDING
              end
            else
              @direction = ASCENDING
            end
          else
            raise "invalid order str #{str}"
          end
        end

        def ascending?
          @direction == ASCENDING
        end

        def descending?
          @direction == DESCENDING
        end
      end
    end

    class Limit
      def initialize(limit)
        @limit = limit
      end

      def limit(records)
        records[0..(@limit -1)]
      end
    end

    class Offset
      def initialize(offset)
        @offset = offset
      end

      def offset(records)
        records[@offset..-1]
      end
    end

    class Join
      attr_reader :join_spec
      def initialize(join_spec)
        @join_spec = join_spec
      end
    end
  end
end
