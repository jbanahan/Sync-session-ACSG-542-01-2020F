require 'open_chain/custom_handler/generator_315/abstract_315_dispatcher'
require 'open_chain/custom_handler/generator_315/isf_315_xml_generator'

module OpenChain; module CustomHandler; module Generator315
  class Isf315Dispatcher < OpenChain::CustomHandler::Generator315::Abstract315Dispatcher

    GENERATORS ||= {standard_xml: OpenChain::CustomHandler::Generator315::Isf315XmlGenerator}.freeze

    def accepts? _event, isf
      # Just check if the customer has a 315 setup, at this point..if so, then accept.  We'll decide in receive if we're actually generating anythign
      # or not.
      MasterSetup.get.custom_feature?("ISF 315") && isf.importer_account_code.present? && configs(isf).size > 0
    end

    def receive _event, isf
      setups = configs(isf)
      setups.each do |setup|
        matches = setup.search_criterions.collect {|sc| sc.test? isf}.uniq.compact
        milestones = []
        if setup.search_criterions.length == 0 || (matches.length == 1 && matches[0] == true)
          # Prevent any other 315 processes for this isf from running, otherwise, it's possible
          # for race conditions between backend processes to produce multiple 315's for the same isf/event
          Lock.acquire("315-#{isf.host_system_file_number}") do
            fingerprint_values = fingerprint_field_data isf, user, setup

            setup.milestone_fields.each do |field|
              milestones << process_field(field.with_indifferent_access, user, isf, setup.testing?, setup.gtn_time_modifier?, fingerprint_values)
            end
          end
        end
        milestones.compact!

        if milestones.size > 0
          # The generator list will eventually include TradeLens
          generator = GENERATORS[:standard_xml]
          generator.new.generate_and_send_315s setup, isf, milestones, setup.testing?
        end
      end

      isf
    end

    private

    def configs isf
      @configs ||= begin
        # Since we can now potentially have multiple configs per customer (since you can have different statuses on the setups),
        # we need to collect all of them that are enabled.
        configs = []
        configs.push(*MilestoneNotificationConfig.where(module_type: "SecurityFiling", customer_number: isf.importer_account_code, enabled: true)
                                                 .order(:id).all.reject(&:tradelens_output?))
        parent_system_code = isf.importer&.parent_system_code
        if parent_system_code.present?
          configs.push(*MilestoneNotificationConfig.where(module_type: "SecurityFiling", parent_system_code: parent_system_code, enabled: true)
                                                   .order(:id).all.reject(&:tradelens_output?))
        end
        configs
      end
    end
  end

end; end; end
