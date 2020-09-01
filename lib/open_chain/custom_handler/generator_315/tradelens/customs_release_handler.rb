require 'open_chain/custom_handler/generator_315/tradelens/entry_field_handler'

module OpenChain; module CustomHandler; module Generator315; module Tradelens
  class CustomsReleaseHandler < OpenChain::CustomHandler::Generator315::Tradelens::EntryFieldHandler

    def endpoint
      "/api/v1/genericEvents/customsRelease"
    end

    def create_315_data entry, data, milestone
      filler = data_315_filler(entry, data, milestone)
      filler.add_entry_port
      filler.data_315
    end

  end

end; end; end; end
