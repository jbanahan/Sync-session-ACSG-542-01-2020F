require "open_chain/events/event_handler"
require "open_chain/events/entry_events/landed_cost_report_attacher_listener"

module OpenChain; module Events; module EntryEvents
  class EntryEventHandler
    include OpenChain::Events::EventHandler

    def listeners event
      listeners = []
      case event.event_type
      when :save
        listeners << LandedCostReportAttacherListener.new
      end

      listeners
    end

  end
end; end; end