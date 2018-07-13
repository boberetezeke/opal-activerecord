module ActiveRecord
  class MemoryStore < AbstractStore
    class Table < Hash
      def get_all_record_attributes
      end
    end

    attr_reader :tables

    def initialize
      super

      @tables = {}
      @table_store_ids = {}
      @next_ids = {}
    end

    def execute(select_manager)
      init_new_table(select_manager.table_name)
      table =  @tables[select_manager.table_name.to_s].values.map{|value| {select_manager.table_name => value} }
      debug "MemoryStore#execute: table name = #{select_manager.table_name}"
      debug "MemoryStore#execute: tables = #{@tables.keys}"
      debug "MemoryStore#node = #{select_manager.node}"
      debug "MemoryStore#execute(begin): table = #{table.inspect}"
      table = execute_join(select_manager, table)
      debug "MemoryStore#execute(end): table = #{table.inspect}"
      records = filter(table, select_manager)
      debug "MemoryStore#execute: result = #{records.inspect}"
      records
    end

    def push(table_name, record)
      init_new_table(table_name)
      store_record_on_table(@tables[table_name], record.id, record)
    end

    def find(klass, table_name, id)
      record = raw_find(table_name, id)
      if record
        klass.new(record)
      else
        raise ActiveRecord::RecordNotFound.new("Record not found: class #{klass}, id #{id.inspect}") unless record
      end
    end
    
    def raw_find(table_name, id)
      #puts "in find(#{id}): #{@tables[table_name].inspect}"

      if @tables[table_name]
        record = get_record_from_table(@tables[table_name], id)
      else
        record = nil
      end
      record
    end

    def create(klass, table_name, record, options={})
      debug "MemoryStore#create(#{record})"
      init_new_table(table_name)
      next_id = gen_next_id(table_name)
      store_record_on_table(@tables[table_name], next_id, record.attributes.dup.merge({"id" =>  next_id}))
      notify_observers(:insert, record, options)
      return next_id
    end

    def update(klass, table_name, record, options={})
      debug "MemoryStore#update(#{record})"
      init_new_table(table_name)
      table = @tables[table_name]
      old_attributes = get_record_from_table(table, record.id)
      store_record_on_table(table, record.id, record.attributes.dup)
      if old_attributes
        notify_observers(:update, record, options) if record.attributes != old_attributes
      else
        notify_observers(:insert, record, options)
      end
    end

    def update_id(klass, table_name, old_id, new_id, options={})
      table = @tables[table_name]
      record = remove_record_from_table(table, old_id)
      store_id = @table_store_ids[table_name].delete(old_id)
      store_id.resolve_to(new_id) if store_id
      store_record_on_table(table, store_id, record)

      #record['id'] = new_id
      #store_record_on_table(table, new_id, record)
    end

    def destroy(klass, table_name, record, options={})
      notify_observers(:delete, record, options)
      remove_record_from_table(@tables[table_name], record.id)
    end

    def all_for_table(table_name)
      @tables[table_name].values
    end

    def to_s
      "tables: #{@tables.inspect}, next_ids: #{@next_ids.inspect}"
    end

    protected

    def get_all_record_attributes(table_name)
      @tables[table_name].values
    end

    def get_table(table_name)
      @tables[table_name]
    end

    private

    def gen_next_id(table_name)
      #next_id = @next_ids[table_name]
      #@next_ids[table_name] += 1
      #return "T-#{next_id}"
      id = @next_ids[table_name].next_id
      @table_store_ids[table_name][id] = id
      id
    end

    def init_new_table(table_name)
      @tables[table_name] ||= {}
      @table_store_ids[table_name] ||= {}      
      @next_ids[table_name] ||= StoreIdGenerator.new # 1
    end

    def store_record_on_table(table, id, record)
      table[id.to_s] = record
    end

    def update_record_hash_key(table, old_id, new_id)
      record = table.delete(old_id.to_s)
      table[new_id.to_s] = record
    end

    def get_record_from_table(table, id)
      table[id.to_s]
    end

    def remove_record_from_table(table, id)
      table.delete(id.to_s)
    end
  end
end
