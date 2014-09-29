module ActiveRecord
  class Association
    attr_reader :foreign_key, :association_type, :name

    def initialize(klass, association_type, name, options, connection)
      @association_type = association_type
      @klass = klass
      @name = name
      @options = options
      @connection = connection
      if @association_type == :belongs_to
        @foreign_key =  "#{name}_id"
      elsif @association_type == :has_many
        @foreign_key = "#{@klass.table_name.singularize}_id"
      end
    end

    def table_name
      (@association_type == :belongs_to) ? @name.to_s + "s" : @name.to_s
    end

    def klass
      Object.const_get(table_name.singularize.camelize)
    end

    def all
      where(1 => 1)
    end
    alias load all

    def where(query={})
      Relation.new(query, @connection) 
    end

    def to_s
      "#Association: #{@name}: #{@association_type}"
    end
  end
end
