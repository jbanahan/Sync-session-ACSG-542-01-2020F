require 'open_chain/events/event_broadcaster'

# Include this module as a means for providing a method to broadcast events ocurring on an object.
# This module is only suitable at the moment to be included on classes that extend ActiveRecord::Base
module BroadcastsEvents

  def broadcast_event event_type, event_context = nil
    @broadcaster ||= OpenChain::Events::EventBroadcaster.new
    @broadcaster.broadcast event_type, self.class.name, self.id, event_context
    nil
  end
end