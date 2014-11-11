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
        if through = @association.options[:through]
          through_association = @association.source_klass.associations[through.to_s]

          source_klass = @owner.class
          through_klass = through_association.klass
          destination_klass = @association.klass

          destination_to_through_association = find_association(destination_klass, through_klass)
          through_to_source_association =      find_association(through_klass, source_klass)

          raise "through to source association not found" unless through_to_source_association
          raise "destination association on through class not found" unless destination_to_through_association
          raise "appending to has_many :through, :through is not supported" if destination_to_through_association.association_type == :belongs_to

          obj.save unless obj.persisited?
          join_table_obj = through_klass.new(destination_to_through_association.foreign_key => obj.id, through_to_source_association.foreign_key => @owner.id)
          join_table_obj.save
        else
          obj.write_attribute(@association.foreign_key, @owner.id)
          obj.save
        end
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
      if through = @association.options[:through]
        through_association = @association.source_klass.associations[through.to_s]

        source_klass = @owner.class
        through_klass = through_association.klass
        destination_klass = @association.klass

        destination_to_through_association = find_association(destination_klass, through_klass)
        through_to_source_association =      find_association(through_klass, source_klass)

        raise "destination association on through class not found" unless destination_to_through_association

        if destination_to_through_association.association_type == :has_many
          Relation.new(@connection, destination_klass, destination_klass.table_name).
              joins(through_klass.table_name => source_klass.table_name.singularize).
              where(through_klass.arel_table[destination_to_through_association.foreign_key].eq(destination_klass.arel_table[:id]).
                and(through_klass.arel_table[through_to_source_association.foreign_key].eq(@owner.id))
              )
        else
          Relation.new(@connection, destination_klass, destination_klass.table_name).
              joins(through_klass.table_name.singularize => source_klass.table_name.singularize).
              where(
                destination_klass.arel_table[destination_to_through_association.foreign_key].eq(through_klass.arel_table[:id]).
                and(through_klass.arel_table[through_to_source_association.foreign_key].eq(@owner.id))
              )
        end
      else
        Relation.new(@connection, @association.klass, @association.table_name).where(where_clause => @owner.id)
      end
    end

    def find_association(from_klass, to_klass)
      from_klass.associations.values.select do |assoc|
        assoc.klass == to_klass
      end.first
    end
  end
end
