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
      @next_ids = {}
    end

    def execute(select_manager)
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
      @tables[table_name][record.id] = record
    end

    def find(klass, table_name, id)
      if @tables[table_name]
        record = @tables[table_name][id]
      else
        record = nil
      end

      if record
        klass.new(record)
      else
        raise ActiveRecord::RecordNotFound.new("Record not found: class #{klass}, id #{id}") unless record
      end
    end

    def create(klass, table_name, record, options={})
      debug "MemoryStore#Create(#{record})"
      init_new_table(table_name)
      next_id = gen_next_id(table_name)
      @tables[table_name][next_id] = record.attributes.dup.merge({"id" =>  next_id})
      notify_observers(:insert, record, options)
      return next_id
    end

    def update(klass, table_name, record, options={})
      init_new_table(table_name)
      table = @tables[table_name]
      old_attributes = table[record.id]
      if old_attributes
        notify_observers(:update, record, options) if record.attributes != old_attributes
      end
      table[record.id] = record.attributes.dup
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

    def gen_next_id(table_name)
      next_id = @next_ids[table_name]
      @next_ids[table_name] += 1
      return "T-#{next_id}"
    end

    def init_new_table(table_name)
      @tables[table_name] ||= {}
      @next_ids[table_name] ||= 1
    end

  end
end
