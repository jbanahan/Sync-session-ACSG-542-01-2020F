require 'open_chain/custom_handler/generator_315/abstract_315_xml_generator'

module OpenChain; module CustomHandler; module Generator315
  class Isf315XmlGenerator < OpenChain::CustomHandler::Generator315::Abstract315XmlGenerator

    protected

    def create_315_data isf, split_data, milestone
      d = Data315.new
      d.customer_number = v(:sf_broker_customer_number, isf)
      d.broker_reference = v(:sf_host_system_file_number, isf)
      d.entry_number = v(:sf_transaction_number, isf)
      d.ship_mode = v(:sf_transport_mode_code, isf)
      d.carrier_code = v(:sf_scac, isf)
      d.vessel = v(:sf_vessel, isf)
      d.voyage_number = v(:sf_voyage, isf)
      d.port_of_entry = v(:sf_entry_port_code, isf)
      d.port_of_entry_location = isf.entry_port
      d.port_of_lading = v(:sf_lading_port_code, isf)
      d.port_of_lading_location = isf.lading_port
      d.port_of_unlading = v(:sf_unlading_port_code, isf)
      d.port_of_unlading_location = isf.unlading_port

      d.master_bills = split_data[:master_bills]
      d.container_numbers = split_data[:container_numbers]
      d.house_bills = split_data[:house_bills]
      d.po_numbers = v(:sf_po_numbers, isf)
      d.event_code = milestone.code
      d.event_date = milestone.date
      d.sync_record = milestone.sync_record
      d.datasource = "isf"

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
        values = values.presence || [{master_bills: [nil], container_numbers: [nil], house_bills: [nil]}]
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
        values = master_bills.map {|mb| {master_bills: [mb], container_numbers: containers, house_bills: house_bills}}
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_HBOL
        values = house_bills.map {|hb| {master_bills: master_bills, container_numbers: containers, house_bills: [hb]}}
      else
        values << {master_bills: master_bills, container_numbers: containers, house_bills: house_bills}
      end
      values
    end
  end

end; end; end
