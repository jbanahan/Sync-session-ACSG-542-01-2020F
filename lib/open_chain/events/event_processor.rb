require "open_chain/events/entry_events/entry_event_handler"

# This class is quite simple at the moment, but at some point this class will be responsible
# in some way for retrieving queued events in an orderly manner, passing them to the handler and 
# then marking the events as completed.
module OpenChain; module Events
  class EventProcessor

    def process_event event
      # Handler should define following methods: handle
      handler = module_event_handler event

      if handler
        handler.handle event
      else
        # If no handler was set up raise an error, since it means something's calling publish on a module 
        # that has nothing set up to handle it.  The event handling is expected to occur only at
        # "critical" moments of the system so any time publish is called there should be a handler for it.
        raise "No module event hander is configured for #{event.object_class} events."
      end

      nil
    end

    protected 
      def module_event_handler event
        handler = nil
        case event.object_class
        when Entry.name
          handler = EntryEvents::EntryEventHandler.new
        end

        handler
      end

  end

  class OpenChainEvent
    # While you can use any value you want for event_type or event_context they must be serializable.  A symbol is the prefered type.
    attr_accessor :event_type, :event_context, :object_class, :object_id
  end

end; end