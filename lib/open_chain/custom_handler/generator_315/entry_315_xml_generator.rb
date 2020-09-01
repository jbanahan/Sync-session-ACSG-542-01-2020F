require 'open_chain/custom_handler/generator_315/abstract_315_xml_generator'

module OpenChain; module CustomHandler; module Generator315
  class Entry315XmlGenerator < OpenChain::CustomHandler::Generator315::Abstract315XmlGenerator

    protected

    def create_315_data entry, data, milestone
      d = Data315.new
      d.customer_number = v(:ent_cust_num, entry)
      d.broker_reference = v(:ent_brok_ref, entry)
      d.entry_number = v(:ent_entry_num, entry)
      d.ship_mode = v(:ent_transport_mode_code, entry)
      d.service_type = v(:ent_fcl_lcl, entry)
      d.carrier_code = v(:ent_carrier_code, entry)
      d.vessel = v(:ent_vessel, entry)
      d.voyage_number = v(:ent_voyage, entry)
      # Load the Locode if the entry is non-US
      if entry.canadian?
        d.port_of_entry = entry.ca_entry_port.try(:unlocode)
        raise "Missing UN Locode for Canadian Port Code #{entry.entry_port_code}." if entry.ca_entry_port && d.port_of_entry.blank?
        d.port_of_entry_location = entry.ca_entry_port
      else
        d.port_of_entry = v(:ent_entry_port_code, entry)
        d.port_of_entry_location = entry.us_entry_port
      end

      d.port_of_lading = v(:ent_lading_port_code, entry)
      d.port_of_lading_location = entry.lading_port
      d.port_of_unlading = v(:ent_unlading_port_code, entry)
      d.port_of_unlading_location = entry.unlading_port

      # Technically, we'd like to put the cargo control number in a collection element (see generate_315_support#write_315_xml)
      # like the master bills etc.
      # However, since this was added a long time after original development, there's a lot of production edi mappings
      # that rely on it being in a a single element.
      # The join here is in keeping with the existing style of handling the cargo control number...in cases where the
      # document is split on the CCN value, each data object received here will have a single one and it won't be any issue parsing it out
      # for ecs
      d.cargo_control_number = data[:cargo_control_numbers].join("\n ") if data[:cargo_control_numbers]
      d.master_bills = data[:master_bills]
      d.container_numbers = data[:container_numbers]
      d.house_bills = data[:house_bills]
      d.po_numbers = Entry.split_newline_values(v(:ent_po_numbers, entry).to_s)
      d.event_code = milestone.code
      d.event_date = milestone.date
      d.sync_record = milestone.sync_record
      d.datasource = "entry"

      d
    end

    def split_entry_data_identifiers output_style, entry
      # We need to send distinct combinations of the broker reference / container / master bill
      # So if we have 2 containers and 2 master bills, then we end up sending 4 documents.
      master_bills = Entry.split_newline_values(v(:ent_mbols, entry).to_s)
      containers = Entry.split_newline_values(v(:ent_container_nums, entry).to_s)
      house_bills = Entry.split_newline_values(v(:ent_hbols, entry).to_s)
      cargo_control_numbers = Entry.split_newline_values(v(:ent_cargo_control_number, entry).to_s)
      values = []
      if output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
        master_bills.each do |mb|
          if containers.length > 0
            containers.each {|c| values << {master_bills: [mb], container_numbers: [c], house_bills: house_bills, cargo_control_numbers: cargo_control_numbers} }
          else
            values << {master_bills: [mb], container_numbers: [nil], house_bills: house_bills, cargo_control_numbers: cargo_control_numbers}
          end
        end
        values.presence || [{master_bills: [nil], container_numbers: [nil], house_bills: house_bills, cargo_control_numbers: cargo_control_numbers}]
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
        values = master_bills.map {|mb| {master_bills: [mb], container_numbers: containers, house_bills: house_bills, cargo_control_numbers: cargo_control_numbers}}
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_HBOL
        values = house_bills.map {|hb| {master_bills: master_bills, container_numbers: containers, house_bills: [hb], cargo_control_numbers: cargo_control_numbers}}
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_CCN
        values = cargo_control_numbers.map { |ccn| {master_bills: master_bills, container_numbers: containers, house_bills: house_bills, cargo_control_numbers: [ccn]}}
      else
        values << {master_bills: master_bills, container_numbers: containers, house_bills: house_bills, cargo_control_numbers: cargo_control_numbers}
      end
      values
    end
  end

end; end; end
