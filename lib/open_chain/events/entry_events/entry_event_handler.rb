require "open_chain/events/event_handler"
require "open_chain/events/entry_events/landed_cost_report_attacher_listener"
require 'open_chain/custom_handler/under_armour/under_armour_315_generator'
require 'open_chain/custom_handler/crocs/crocs_210_generator'
require 'open_chain/custom_handler/foot_locker/foot_locker_810_generator'

module OpenChain; module Events; module EntryEvents
  class EntryEventHandler
    include OpenChain::Events::EventHandler

    def listeners event
      listeners = []
      case event.event_type
      when :save
        listeners << LandedCostReportAttacherListener.new
        listeners << OpenChain::CustomHandler::UnderArmour::UnderArmour315Generator.new
        listeners << OpenChain::CustomHandler::Crocs::Crocs210Generator.new
        listeners << OpenChain::CustomHandler::FootLocker::FootLocker810Generator.new
      end

      listeners
    end

  end
end; end; end