# This event handler should be ok to use for any object that has a class method named "find_by_id" (which includes any ActiveRecord::Base classes)
#
# Implementations of this class must define the method "listeners" which will be pased an OpenChainEvent object.
# The method must return an Enumerable object containing the listener classes to be evaluated for the current event.
#
# Listeners objects must implement the following methods:
#
# - "accepts?" - will be passed the event and the corresponding object the event occurred on. 
# This method must return a truthy value to indicate that the listener's 'receive' should be called.
#
# - "receive" - will be passed the event and the corresponding object the event occurred on. 
# Any action / process that should occur when the event executes should be carried out here.  Because
# multiple listeners are chained together, you may modify the object and return it and the returned 
# object will be utilized for any listeners run after the current one.
#
module OpenChain; module Events
  module EventHandler

    # This is the only external API that is utilized when processing an event.
    def handle event
      module_object = find event
      listeners = filter_listeners event, module_object
      run_listeners listeners, event, module_object

      # We don't want to even suggest that anything may be returned here.
      nil
    end

    # Find the actual object that this event relates to. 
    def find event
      # constantize handles namespaced classes, const_get doesn't
      klass = event.object_class.constantize
      # This call relies on the find_by_id ActiveRecord method being in place on the object
      klass.find_by_id(event.object_id)
    end

    # Narrows down the full listener list to only those listeners that will accept this
    # entry.
    def filter_listeners event, module_object
      # listeners is a method which returns a list of listeners for each event type
      event_listeners = []
      listeners(event).each do |listener|
        if listener.accepts? event, module_object
          event_listeners << listener
        end
      end

      event_listeners
    end

    # Executes each listener sequentially in the order the implementing class returns them.
    def run_listeners listeners, event, module_object
      listeners.each do |listener|

        # Listeners can modify the object passed to them and return it so 
        # it can be used further down the call chain.
        begin
          obj = process_listener listener, event, module_object

          if obj
            module_object = obj
          end
        rescue 
          # Don't let an errant issue in a listener blow up the whole chain
          $!.log_me
        end
      end
    end

    # Runs a single event listener
    def process_listener listener, event, module_object
      obj = listener.receive event, module_object

      # Just some precautionary work to make sure someone didn't accidently
      # return an object from the listener that's not the expected module type.
      if obj && obj.class == module_object.class
        obj
      else 
        nil
      end
    end
  end
end; end