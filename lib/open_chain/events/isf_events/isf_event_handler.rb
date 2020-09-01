require 'open_chain/events/event_handler'
require 'open_chain/custom_handler/generator_315/isf_315_xml_generator'

module OpenChain; module Events; module IsfEvents; class IsfEventHandler
  include OpenChain::Events::EventHandler

  def listeners event
    listeners = []
    case event.event_type
    when :save
      listeners << OpenChain::CustomHandler::Generator315::Isf315Dispatcher.new
    end

    listeners
  end

end; end; end; end
