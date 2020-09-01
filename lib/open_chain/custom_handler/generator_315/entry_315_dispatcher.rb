require 'open_chain/custom_handler/generator_315/abstract_315_dispatcher'
require 'open_chain/custom_handler/generator_315/entry_315_xml_generator'
require 'open_chain/custom_handler/generator_315/tradelens/entry_315_tradelens_generator'

module OpenChain; module CustomHandler; module Generator315
  class Entry315Dispatcher < OpenChain::CustomHandler::Generator315::Abstract315Dispatcher

    GENERATORS ||= {tradelens: OpenChain::CustomHandler::Generator315::Tradelens::Entry315TradelensGenerator,
                    standard_xml: OpenChain::CustomHandler::Generator315::Entry315XmlGenerator}.freeze

    def accepts? _event, entry
      # Just check if the customer has a 315 setup, at this point..if so, then accept.  We'll decide in receive if we're actually generating anythign
      # or not.
      MasterSetup.get.custom_feature?("Entry 315") && entry.customer_number.present? && configs(entry).size > 0
    end

    def receive _event, entry
      setups = configs(entry)

      setups.each do |setup|
        matches = setup.search_criterions.collect {|sc| sc.test? entry}.uniq.compact
        milestones = []
        if setup.search_criterions.length == 0 || (matches.length == 1 && matches[0] == true)
          # Prevent any other 315 processes for this entry from running, otherwise, it's possible
          # for race conditions between backend processes to produce multiple 315's for the same entry/event
          Lock.acquire("315-#{entry.broker_reference}") do
            fingerprint_values = fingerprint_field_data entry, user, setup

            setup.milestone_fields.each do |field|
              milestones << process_field(field.with_indifferent_access, user, entry, setup.testing?, setup.gtn_time_modifier?, fingerprint_values)
            end
          end
        end
        milestones.compact!

        if milestones.size > 0
          generator = GENERATORS[setup.output_context]
          generator.new.generate_and_send_315s setup, entry, milestones, setup.testing?
        end
      end

      entry
    end

    private

    def configs entry
      @configs ||= begin
        # Since we can now potentially have multiple configs per customer (since you can have different statuses on the setups),
        # we need to collect all of them that are enabled.
        configs = []
        configs.push(*MilestoneNotificationConfig.where(module_type: "Entry", customer_number: entry.customer_number, enabled: true)
                                                 .order(:id).all)
        parent_system_code = entry.importer&.parent_system_code

        if parent_system_code.present?
          configs.push(*MilestoneNotificationConfig.where(module_type: "Entry", parent_system_code: parent_system_code, enabled: true)
                                                   .order(:id).all)
        end
        configs
      end
    end
  end

end; end; end
