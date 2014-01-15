require 'open_chain/events/event_processor'

# This is mostly a shim class at this point, but it will eventually
# be added to in order to truly make event processing asynchronous (ie. it will queue
# event records to some sort of backend event processing queue)

module OpenChain; module Events
  class EventBroadcaster

    # Only for testing purposes
    attr_reader :broadcasted_events

    def initialize process_events = Rails.configuration.broadcast_model_events
      @processor = EventProcessor.new
      @process_events = process_events
    end

    def broadcast event_type, object_class, object_id, event_context = nil
      event = make_event(event_type, object_class, object_id, event_context)
      begin
        # Since the event listeners generally do things like send out files (billing files / 315s) and other 
        # things that absolutely shouldn't get sent in test or development modes we're just going to store 
        # the events off in these modes and only actually process events in production mode
        if @process_events
          @processor.process_event event
        else
          @broadcasted_events ||= []
          @broadcasted_events << event
        end
        
      rescue
        $!.log_me
      end
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