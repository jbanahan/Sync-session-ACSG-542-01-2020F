require 'open_chain/custom_handler/generator_315_support'

module OpenChain; module CustomHandler; class Generic315Generator
  include OpenChain::CustomHandler::Generator315Support

  def accepts? event, entry
    # Just check if the customer has a 315 setup, at this point..if so, then accept.  We'll decide in receive if we're actually generating anythign
    # or not.
    MasterSetup.get.custom_feature?("Entry 315") && !entry.customer_number.blank? && setup_315(entry).size > 0
  end

  def receive event, entry
    setups = setup_315(entry)

    setups.each do |setup|
      matches = setup.search_criterions.collect {|sc| sc.test? entry}.uniq.compact
      user = User.integration
      milestones = []
      if setup.search_criterions.length == 0 || (matches.length == 1 && matches[0] == true)
        # Prevent any other 315 processes for this entry from running, otherwise, it's possible
        # for race conditions between backend processes to produce multiple 315's for the same entry/event
        Lock.acquire("315-#{entry.broker_reference}") do
          setup.setup_json.each do |field|
            milestones << process_field(field.with_indifferent_access, user, entry)
          end
        end
      end
      milestones.compact!

      if milestones.size > 0
        generate_and_send_315s setup.output_style, entry, milestones, setup.testing?
      end
    end
    
    
    entry
  end

  def generate_and_send_315s output_style, entry, milestones, testing = false
    split_entries = split_entry_data_identifiers output_style, entry
    data_315s = []

    split_entries.each do |data|
      milestones.each do |milestone|
        data_315s << create_315_data(entry, data, milestone)
      end
    end

    generate_and_send_xml_document(entry.customer_number, data_315s, testing) do |data_315|
      DataCrossReference.create_315_milestone! entry, data_315.event_code, xref_date_value(data_315.event_date)
    end
   
    nil
  end

  protected

    def create_315_data entry, data, milestone
      d = Data315.new
      d.broker_reference = v(:ent_brok_ref, entry)
      d.entry_number = v(:ent_entry_num, entry)
      d.ship_mode = v(:ent_transport_mode_code, entry)
      d.service_type = v(:ent_fcl_lcl, entry)
      d.carrier_code = v(:ent_carrier_code, entry)
      d.vessel = v(:ent_vessel, entry)
      d.voyage_number = v(:ent_voyage, entry)
      d.port_of_entry = v(:ent_entry_port_code, entry)
      d.port_of_lading = v(:ent_lading_port_code, entry)
      d.cargo_control_number = v(:ent_cargo_control_number, entry)
      d.master_bills = data[:master_bills]
      d.container_numbers = data[:container_numbers]
      d.house_bills = data[:house_bills]
      d.po_numbers = v(:ent_po_numbers, entry)
      d.event_code = milestone.code
      d.event_date = milestone.date

      d
    end

  private 

    def split_entry_data_identifiers output_style, entry
      # We need to send distinct combinations of the broker reference / container / master bill
      # So if we have 2 containers and 2 master bills, then we end up sending 4 documents.
      master_bills = v(:ent_mbols, entry).to_s.split(/\n\s*/)
      containers = v(:ent_container_nums, entry).to_s.split(/\n\s*/)
      house_bills = v(:ent_hbols, entry).to_s.split(/\n\s*/)
      values = []
      if output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
        master_bills.each do |mb|
          if containers.length > 0
            containers.each {|c| values << {master_bills: [mb], container_numbers: [c], house_bills: house_bills} }
          else
            values << {master_bills: [mb], container_numbers: [nil], house_bills: house_bills}
          end
        end
        values = values.blank? ? [{master_bills: [nil], container_numbers: [nil], house_bills: house_bills}] : values
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
        values = master_bills.map {|mb| {master_bills: [mb], container_numbers: containers, house_bills: house_bills}}
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_HBOL
        values = house_bills.map {|hb| {master_bills: master_bills, container_numbers: containers, house_bills: [hb]}}
      else
        values << {master_bills: master_bills, container_numbers: containers, house_bills: house_bills}
      end
      values
    end
  
    def setup_315 entry
      @cache ||= Hash.new do |h, k|
        # Since we can now potentially have multiple configs per customer (since you can have different statuses on the setups),
        # we need to collect all of them that are enabled.
        h[k] = MilestoneNotificationConfig.where(module_type: "Entry", customer_number: k, enabled: true).order(:id).all
      end

      @cache[entry.customer_number]
    end

end; end; end;