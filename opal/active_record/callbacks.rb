module ActiveRecord
  module Callbacks
    class Callback
      attr_reader :temporality, :action
      def initialize(temporality, action, arguments)
        @temporality = temporality.to_s
        @action = action.to_s
        @arguments = arguments
      end

      def invoke(object)
        method_name = @arguments.first
        object.send(method_name)
      end
    end

    class CallbackSet
      attr_reader :befores, :afters, :arounds

      def initialize
        @befores = []
        @afters = []
        @arounds = []
      end

      def add_callback(callback)
        case callback.temporality
        when 'before'
          @befores.push(callback)
        when 'after'
          @afters.push(callback)
        when 'around'
          @arounds.push(callback)
        end
      end
    end

    module ClassMethods
      def add_callback(temporality, action, arguments)
        @callbacks ||= {}
        @callbacks[action.to_s] ||= ActiveRecord::Callbacks::CallbackSet.new
        @callbacks[action.to_s].add_callback(ActiveRecord::Callbacks::Callback.new(temporality, action, arguments))
      end

      def invoke_callback(object, action, block)
        @callbacks ||= {}

        callback_set = @callbacks[action.to_s]
        if callback_set
          callback_set.befores.each{ |cb| cb.invoke(object) }

          block.call

          callback_set.afters.each{ |cb| cb.invoke(object) }
        else
          block.call
        end
      end
    end

    module InstanceMethods
      def callbackable(action, &block)
        self.class.invoke_callback(self, action, block)
      end
    end
  end
end
