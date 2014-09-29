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

    def record_matches(record, select_manager)
      debug "LocalStorageStore#execute: node: #{select_manager.node}, checking record: #{record}"
      select_manager.node ?  select_manager.node.value(record) : true
    end
  end
end
