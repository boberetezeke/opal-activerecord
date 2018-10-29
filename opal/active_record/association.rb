module ActiveRecord
  class Association
    attr_reader :foreign_key, :association_type, :name, :source_klass, :options

    def initialize(source_klass, association_type, name, options, connection)
      @association_type = association_type
      @name = name
      @options = options
      @connection = connection
      @source_klass = source_klass
      if @association_type == :belongs_to
        if options[:foreign_key]
          @foreign_key = options[:foreign_key]
        else
          @foreign_key =  "#{name}_id"
        end
      elsif @association_type == :has_many || @association_type == :has_one
        puts "Association#initialize: in has_many"
        if options[:foreign_key]
          @foreign_key = options[:foreign_key]
        else
          @foreign_key = "#{singularize(source_klass.table_name)}_id"
        end
      end
    end

    def table_name
      if options[:class_name]
        class_name = options[:class_name]
        (@association_type == :belongs_to) ? class_name.underscore.pluralize : class_name.underscore
      else
        (@association_type == :belongs_to) ? @name.to_s.pluralize : @name.to_s
      end
    end

    def klass
      if options[:class_name]
        Object.const_get(options[:class_name])
      else
        const_name = singularize(table_name).camelize
        Object.const_get(const_name)
        #Object.const_get(table_name.singularize.camelize)
      end
    end

    def all
      where(1 => 1)
    end
    alias load all

    def to_s
      "#Association: (#{@source_klass} #{@association_type}: #{@name}): foreign_key: #{@foreign_key}"
    end

    def hash
      name.to_s.hash
    end

    def singularize(str)
      s = str.singularize
      s ? s : str
    end
  end
end
