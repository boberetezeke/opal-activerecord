module ActiveRecord
  class AbstractStore
    include SemanticLogger::Loggable

    class Observer
      attr_accessor :call_back, :select_manager, :options, :id, :unbinder
      def initialize(call_back, select_manager, options)
        @call_back = call_back
        @select_manager = select_manager
        @options = options
      end

      def unobserve
        @unbinder.call if @unbinder
      end

      def to_s
        "Observer-ID: #{@id}"
      end
    end

    def initialize(*args)
      @observers = []
      @next_id = 1
    end

    def on_change(options={}, &call_back)
      add_observer(Observer.new(call_back, nil, options))
    end

    def on_change_with_select_manager(call_back, select_manager, options={})
      add_observer(Observer.new(call_back, select_manager, options))
    end

    def add_observer(observer)
      @observers.push(observer)
      observer.id = next_id = @next_id
      observer.unbinder = ->{ @observers.delete_if{|o| o.id == next_id } }
      @next_id += 1
      observer
    end

    def notify_observers(change, object, options={})
      debug "notify_observers: change = #{change}, object = #{object}, options = #{options}"
      @observers.each do |observer|
        debug "observer.options = #{observer.options}"

        if observer.options[:local_only]
          next if (options[:from_remote] || options[:local_only])
        end
                
        if observer.options[:remote_only]
          next if !(options[:from_remote])
        end

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

    def execute_join(select_manager, table)
      select_manager.joins.each do |join|
        debug "LocalStorageStore#execute(join): join = #{join.inspect}"
        join.join_spec.each do |association_from, association_to|
          table_name = association_from.table_name
          table_2 = get_all_record_attributes(table_name).map  { |attributes| {table_name => attributes} }
          debug "LocalStorageStore#execute(join): table_2 = #{table_2.inspect}"
          if association_from.association_type == :has_many || association_from.association_type == :has_one
            table = join_tables(table, table_2, select_manager.table_name, 'id', table_name, association_from.foreign_key.to_s)
          else
            table = join_tables(table, table_2, select_manager.table_name, association_from.foreign_key.to_s, table_name, 'id')
          end
          debug "LocalStorageStore#execute(join): table = #{table.inspect}"

          if association_to
            table_name = association_to.table_name
            table_2 = get_all_record_attributes(table_name).map  { |attributes| {table_name => attributes} }
            debug "LocalStorageStore#execute(join2): table_2 = #{table.inspect}"
            if association_to.association_type == :has_many || association_from.association_type == :has_one
              table = join_tables(table, table_2, association_from.table_name, 'id', table_name, association_to.foreign_key.to_s)
            else
              table = join_tables(table, table_2, association_from.table_name, association_to.foreign_key.to_s, table_name, 'id')
            end
            debug "LocalStorageStore#execute(join2): table = #{table.inspect}"
          end
        end
      end

      table
    end

    def filter(records, select_manager)
      select_manager.filter(records).map { |record| select_manager.klass.new(record[select_manager.table_name]) }
    end

    def record_matches(record, select_manager)
      select_manager.record_matches(record)
    end

    class TableJoiner
      include SemanticLogger::Loggable

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
        debug "TableJoiner#initialize: join where #{table1_name}.#{table1_column} == #{table2_name}.#{table2_column}"
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
            inner_join_loop
          end

          break if !next_row(:table1)
        end
      end
      
      def inner_join_loop
        loop do
          push_row
          break if !next_row(:table2_match)
          value1 = value(:table1)
          value2 = value(:table2_match)
          break if value(:table1) != value(:table2_match)
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

      def debug(str)
        logger.debug str, tags: [:ar, :table_joiner]
      end
    end

    def join_tables(table1,  table2, table1_name, table1_column, table2_name, table2_column)
      table_joiner = TableJoiner.new(table1, table2, table1_name, table1_column, table2_name, table2_column)
      table_joiner.join
      result_table = table_joiner.result_table
      # puts "result_table = #{result_table}"
      result_table
    end

    def debug(str)
      logger.debug str, tags: [:abstract_store]
    end
  end
end
