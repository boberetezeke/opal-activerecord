module ActiveRecord
  class CollectionProxy
    def initialize(connection, owner, association)
      @connection = connection
      @owner = owner
      @association = association
    end

    def <<(collection)
      debug "CollectionProxy(owner: #{@owner})#<<(#{collection})"
      collection = [collection] unless collection.is_a?(Array)
      collection.each do |obj|
        obj.write_attribute(@association.foreign_key, @owner.id)
        obj.save
      end
    end

    def where(*args)
      relation.where(*args)
    end

    def method_missing(sym, *args, &block)
      if [:first, :last, :all, :load, :reverse, :empty?].include?(sym)
        debug "CollectionProxy: method_missing: #{sym}"
        relation.send(sym, *args, &block)
      elsif @association.klass.scopes[sym]
        @association.klass.scopes[sym].call
      else
        super
      end
    end

    def present?
      relation.present?
    end

    private

    def relation
      where_clause = "#{@owner.table_name.singularize}_id"
      debug "CollectionProxy: relation: for table: #{@association.table_name}, where: #{where_clause} == #{@owner.id}"
      Relation.new(@connection, @association.klass, @association.table_name).where(where_clause => @owner.id)
    end
  end
end
