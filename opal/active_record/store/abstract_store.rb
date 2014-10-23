module ActiveRecord
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

    def filter(records, select_manager)
      select_manager.filter(records)
    end

    def record_matches(record, select_manager)
      select_manager.record_matches(record)
    end

    class TableJoiner
      class Iterator
        attr_reader :row, :value

        def initialize(table, name, column, index=0)
          @table = table
          @name = name
          @column = column
          @index = index
        end

        def get_row
          @row = @table[@index]
          @value = @row[@name][@column]
        end

        def next_row
          return false if @index >= @table.size - 1
          @index += 1
          get_row
          return true
        end

        def dup
          self.class.new(@table, @name, @column, @index)
        end
      end

      attr_reader :result_table
      def initialize(table1, table2, table1_name, table1_column, table2_name, table2_column)
        @table1 = table1.sort_by{|row| row[table1_name][table1_column]}
        @table2 = table2.sort_by{|row| row[table2_name][table2_column]}

        @iterators = {
            :table1 => Iterator.new(@table1, table1_name, table1_column),
            :table2 => Iterator.new(@table2, table2_name, table2_column)
        }

        @result_table = []
      end

      def join
        # handle if either table is empty
        return if @table1.size == 0 || @table2.size == 0

        loop do
          get_row(:table1)
          get_row(:table2)

          while value(:table1) > value(:table2)
            return if !next_row(:table2)
          end

          if value(:table1) == value(:table2)
            @iterators[:table2_match] = @iterators[:table2].dup
            get_row(:table2_match)
            loop do
              push_row
              break if !next_row(:table2_match)
              value1 = value(:table1)
              value2 = value(:table2_match)
              break if value(:table1) != value(:table2_match)
            end
          end

          break if !next_row(:table1)
        end
      end

      def value(table_sym)
        @iterators[table_sym].value
      end

      def get_row(table_sym)
        @iterators[table_sym].get_row
      end

      def next_row(table_sym)
        @iterators[table_sym].next_row
      end

      def push_row
        @result_table.push(@iterators[:table1].row.dup.merge(@iterators[:table2_match].row))
      end
    end

    def join_tables(table1,  table2, table1_name, table1_column, table2_name, table2_column)
      table_joiner = TableJoiner.new(table1, table2, table1_name, table1_column, table2_name, table2_column)
      table_joiner.join
      result_table = table_joiner.result_table
      # puts "result_table = #{result_table}"
      result_table
    end
  end
end
