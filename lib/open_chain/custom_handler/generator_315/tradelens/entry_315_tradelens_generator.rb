require 'open_chain/custom_handler/generator_315/abstract_315_generator'
require 'open_chain/custom_handler/generator_315/tradelens/entry_field_handler'
require 'open_chain/custom_handler/generator_315/tradelens/customs_release_handler'

module OpenChain; module CustomHandler; module Generator315; module Tradelens
  class Entry315TradelensGenerator < OpenChain::CustomHandler::Generator315::Abstract315Generator

    def self.entry_endpoint_labels
      OpenChain::CustomHandler::Generator315::Tradelens::EntryFieldHandler.endpoint_labels
    end

    def self.security_filing_endpoint_labels
      {}
    end

    def field_handler code
      OpenChain::CustomHandler::Generator315::Tradelens::EntryFieldHandler.handler(code)
    end

    def create_315_data entry, data, milestone
      handler = field_handler(milestone.code)
      handler.create_315_data(entry, data, milestone)
    end

    def generate_and_send_document _customer_number, data_315s, testing = false
      return if data_315s.blank?

      data_315s.each do |data_315|
        handler = field_handler(data_315.event_code)
        session = handler.send_milestone data_315
        data_315.sync_record.api_session = session

        yield data_315 unless testing
      end
    end

    def split_entry_data_identifiers output_style, entry
      master_bills = Entry.split_newline_values(v(:ent_mbols, entry).to_s)
      containers = Entry.split_newline_values(v(:ent_container_nums, entry).to_s)
      house_bills = Entry.split_newline_values(v(:ent_hbols, entry).to_s)
      cargo_control_numbers = Entry.split_newline_values(v(:ent_cargo_control_number, entry).to_s)
      transport_mode_code = v(:ent_transport_mode_code, entry).to_s
      values = []

      if output_style == MilestoneNotificationConfig::OUTPUT_STYLE_TRADELENS_MBOL_CONTAINER_SPLIT
        [master_bills, containers].each { |arr| arr << nil if arr.empty? }
        master_bills.each do |mb|
          values.concat(containers.map do |c|
            {master_bills: [mb], container_numbers: [c], house_bills: house_bills, cargo_control_numbers: cargo_control_numbers,
             transport_mode_code: transport_mode_code}
          end)
        end
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_TRADELENS_MBOL
        values.concat(master_bills.map do |mb|
          {master_bills: [mb], container_numbers: containers, house_bills: house_bills, cargo_control_numbers: cargo_control_numbers,
           transport_mode_code: transport_mode_code}
        end)
      end

      values
    end
  end

end; end; end; end
