require 'open_chain/events/event_processor'

# This is mostly a shim class at this point, but it will eventually
# be added to in order to truly make event processing asynchronous (ie. it will queue
# event records to some sort of backend event processing queue)

module OpenChain; module Events
  class EventBroadcaster

    def initialize
      @processor = EventProcessor.new
    end

    def broadcast event_type, object_class, object_id, event_context = nil
      @processor.process_event make_event(event_type, object_class, object_id, event_context)
    end

    private 
      def make_event event_type, object_class, object_id, event_context
        e = OpenChainEvent.new 
        e.event_type = event_type
        e.object_class = object_class
        e.object_id = object_id
        e.event_context = event_context

        e
      end
  end
end; end