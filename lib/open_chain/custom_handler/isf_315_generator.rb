require 'open_chain/custom_handler/generator_315_support'

module OpenChain; module CustomHandler; class Isf315Generator
  include OpenChain::CustomHandler::Generator315Support

  def accepts? event, isf
    # Just check if the customer has a 315 setup, at this point..if so, then accept.  We'll decide in receive if we're actually generating anythign
    # or not.
    MasterSetup.get.custom_feature?("ISF 315") && !isf.importer_account_code.blank? && setup_315(isf).size > 0
  end

   def receive event, isf
    setups = setup_315(isf)
    setups.each do |setup|
      matches = setup.search_criterions.collect {|sc| sc.test? isf}.uniq.compact
      milestones = []
      if setup.search_criterions.length == 0 || (matches.length == 1 && matches[0] == true)
        # Prevent any other 315 processes for this isf from running, otherwise, it's possible
        # for race conditions between backend processes to produce multiple 315's for the same isf/event
        Lock.acquire("315-#{isf.host_system_file_number}") do
          setup.setup_json.each do |field|
            milestones << process_field(field.with_indifferent_access, user, isf)
          end
        end
      end
      milestones.compact!

      if milestones.size > 0
        generate_and_send_315s setup.output_style, isf, milestones, setup.testing?
      end
    end
    
    isf
  end

  def generate_and_send_315s output_style, isf, milestones, testing = false
    split_isfs = split_entry_data_identifiers output_style, isf
    data_315s = []

    split_isfs.each do |data|
      milestones.each do |milestone|
        data_315s << create_315_data(isf, data, milestone)
      end
    end

    generate_and_send_xml_document(isf.importer_account_code, data_315s, testing) do |data_315|
      DataCrossReference.create_315_milestone! isf, data_315.event_code, xref_date_value(data_315.event_date)
    end
   
    nil
  end

  private

    def create_315_data isf, split_data, milestone
      d = Data315.new
      d.broker_reference = v(:sf_host_system_file_number, isf)
      d.entry_number = v(:sf_transaction_number, isf)
      d.ship_mode = v(:sf_transport_mode_code, isf)
      d.carrier_code = v(:sf_scac, isf)
      d.vessel = v(:sf_vessel, isf)
      d.voyage_number = v(:sf_voyage, isf)
      d.port_of_entry = v(:sf_entry_port_code, isf)
      d.port_of_lading = v(:sf_lading_port_code, isf)
      
      d.master_bills = split_data[:master_bills]
      d.container_numbers = split_data[:container_numbers]
      d.house_bills = split_data[:house_bills]
      d.po_numbers = v(:sf_po_numbers, isf)
      d.event_code = milestone.code
      d.event_date = milestone.date

      d
    end

    def split_entry_data_identifiers output_style, isf
      # We need to send distinct combinations of the broker reference / container / master bill
      # So if we have 2 containers and 2 master bills, then we end up sending 4 documents.
      master_bills = v(:sf_master_bill_of_lading, isf).to_s.split(/\n\s*/)
      containers = v(:sf_container_numbers, isf).to_s.split(/\n\s*/)
      house_bills = v(:sf_house_bills_of_lading, isf).to_s.split(/\n\s*/)
      values = []
      if output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
        master_bills.each do |mb|
          if containers.length > 0
            containers.each {|c| values << {master_bills: [mb], container_numbers: [c], house_bills: house_bills} }
          else
            values << {master_bills: [mb], container_numbers: [nil], house_bills: house_bills}
          end
        end
        values = values.blank? ? [{master_bills: [nil], container_numbers: [nil], house_bills: [nil]}] : values
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
        values = master_bills.map {|mb| {master_bills: [mb], container_numbers: containers, house_bills: house_bills}}
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_HBOL
        values = house_bills.map {|hb| {master_bills: master_bills, container_numbers: containers, house_bills: [hb]}}
      else
        values << {master_bills: master_bills, container_numbers: containers, house_bills: house_bills}
      end
      values
    end

    def setup_315 isf
      @cache ||= Hash.new do |h, k|
        # Since we can now potentially have multiple configs per customer (since you can have different statuses on the setups),
        # we need to collect all of them that are enabled.
        h[k] = MilestoneNotificationConfig.where(customer_number: k, enabled: true, module_type: "SecurityFiling").order(:id).all
      end

      @cache[isf.importer_account_code]
    end

end; end; end;