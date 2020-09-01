require 'open_chain/custom_handler/generator_315/abstract_315_generator'
require 'open_chain/ftp_file_support'
require 'open_chain/xml_builder'

module OpenChain; module CustomHandler; module Generator315
  class Abstract315XmlGenerator < OpenChain::CustomHandler::Generator315::Abstract315Generator
    include OpenChain::XmlBuilder
    include OpenChain::FtpFileSupport

    Data315 ||= Struct.new(:broker_reference, :entry_number, :ship_mode, :service_type, :carrier_code, :vessel,
                           :voyage_number, :port_of_entry, :port_of_entry_location, :port_of_lading, :port_of_lading_location,
                           :port_of_unlading, :port_of_unlading_location, :cargo_control_number, :master_bills, :house_bills,
                           :container_numbers, :po_numbers, :customer_number, :event_code, :event_date, :datasource, :sync_record)

    def generate_and_send_document customer_number, data_315s, testing = false
      return if data_315s.blank?

      doc, root = build_xml_document "VfiTrack315s"
      counter = 0
      data_315s = Array.wrap(data_315s)
      data_315s.each do |data|
        write_315_xml root, data
        counter += 1
      end

      if counter > 0
        Tempfile.open(["315-#{data_315s.first.datasource}-#{data_315s.first.broker_reference}-", ".xml"]) do |fout|
          # The FTP send and milestone updates all need to be done in one transaction to ensure all or nothing
          ActiveRecord::Base.transaction do
            doc.write fout
            fout.flush
            fout.rewind
            # Testing files won't have sync records..
            ftp_sync_file fout, data_315s.map(&:sync_record).compact, folder: ftp_folder(customer_number, testing)

            unless testing
              data_315s.each do |milestone|
                yield milestone
              end
            end
          end
        end
      end

      nil
    end

    def write_315_xml parent_element, data
      root = add_element parent_element, "VfiTrack315"
      add_element root, "BrokerReference", data.broker_reference
      add_element root, "EntryNumber", data.entry_number
      add_element root, "CustomerNumber", data.customer_number
      add_element root, "ShipMode", data.ship_mode
      add_element root, "ServiceType", data.service_type
      add_element root, "CarrierCode", data.carrier_code
      add_element root, "Vessel", data.vessel
      # Voyage must be at least 2 chars to fit EDI document standards for the 315, so zero-pad the voyage to 2 chars
      add_element root, "VoyageNumber", data.voyage_number.to_s.rjust(2, "0")
      add_element root, "PortOfEntry", data.port_of_entry
      add_element root, "PortOfLading", data.port_of_lading
      add_element root, "PortOfUnlading", data.port_of_unlading
      write_location_xml(root, data.port_of_entry, "PortOfEntry", data.port_of_entry_location)
      write_location_xml(root, data.port_of_lading, "PortOfLading", data.port_of_lading_location)
      write_location_xml(root, data.port_of_unlading, "PortOfUnlading", data.port_of_unlading_location)
      add_element root, "CargoControlNumber", data.cargo_control_number

      add_collection_element root, "MasterBills", "MasterBill", data.master_bills
      add_collection_element root, "HouseBills", "HouseBill", data.house_bills
      add_collection_element root, "Containers", "Container", data.container_numbers
      add_collection_element root, "PoNumbers", "PoNumber", data.po_numbers

      event = add_element root, "Event"
      add_element event, "EventCode", data.event_code
      add_date_elements event, data.event_date, element_prefix: "Event"

      nil
    end

    def write_location_xml xml, location_code, location_type, port
      return unless port

      location = add_element xml, "Location"
      add_element location, "LocationType", location_type
      add_element location, "LocationCode", location_code
      add_element location, "LocationCodeType", determine_port_code_type(location_code, port)
      add_element location, "Name", port.name
      add_element location, "Address1", port.address&.line_1
      add_element location, "Address2", port.address&.line_2
      add_element location, "Address3", port.address&.line_3
      add_element location, "City", port.address&.city
      add_element location, "State", port.address&.state
      add_element location, "PostalCode", port.address&.postal_code
      add_element location, "Country", port.address&.country&.iso_code
      nil
    end

    def ftp_credentials
      connect_vfitrack_net nil
    end

    def ftp_folder customer_number, testing = false
      if testing
        "to_ecs/315_test/#{customer_number.to_s.upcase}"
      else
        "to_ecs/315/#{customer_number.to_s.upcase}"
      end
    end
  end

end; end; end
