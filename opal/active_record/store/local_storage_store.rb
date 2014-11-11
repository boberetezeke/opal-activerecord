module ActiveRecord
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
      table = table.get_all_record_attributes.map  { |attributes| {select_manager.table_name => attributes} }
      debug "LocalStorageStore#execute(begin): table = #{table.inspect}"
      select_manager.joins.each do |join|
        debug "LocalStorageStore#execute(join): join = #{join.inspect}"
        join.join_spec.each do |association_from, association_to|
          table_name = association_from.table_name
          table_2 = get_table(table_name).get_all_record_attributes.map  { |attributes| {table_name => attributes} }
          debug "LocalStorageStore#execute(join): table_2 = #{table_2.inspect}"
          if association_from.association_type == :has_many
            table = join_tables(table, table_2, select_manager.table_name, 'id', table_name, association_from.foreign_key.to_s)
          else
            table = join_tables(table, table_2, select_manager.table_name, association_from.foreign_key.to_s, table_name, 'id')
          end
          debug "LocalStorageStore#execute(join): table = #{table.inspect}"

          if association_to
            table_name = association_to.table_name
            table_2 = get_table(table_name).get_all_record_attributes.map  { |attributes| {table_name => attributes} }
            debug "LocalStorageStore#execute(join2): table_2 = #{table.inspect}"
            if association_to.association_type == :has_many
              table = join_tables(table, table_2, association_from.table_name, 'id', table_name, association_to.foreign_key.to_s)
            else
              table = join_tables(table, table_2, association_from.table_name, association_to.foreign_key.to_s, table_name, 'id')
            end
            debug "LocalStorageStore#execute(join2): table = #{table.inspect}"
          end
        end
      end
      debug "LocalStorageStore#execute(end): table = #{table.inspect}"
      records = filter(table, select_manager ).map { |record| select_manager.klass.new(record[select_manager.table_name]) }
      debug "LocalStorageStore#execute(end): result = #{records.inspect}"
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
end
