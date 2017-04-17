require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'
require 'digest/sha1'

module OpenChain; module CustomHandler; module Generator315Support
  extend ActiveSupport::Concern
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  Data315 ||= Struct.new(:broker_reference, :entry_number, :ship_mode, :service_type, :carrier_code, :vessel, 
                          :voyage_number, :port_of_entry, :port_of_lading, :cargo_control_number, :master_bills, :house_bills, :container_numbers,
                          :po_numbers, :event_code, :event_date, :datasource, :sync_record)
                          
  MilestoneUpdate ||= Struct.new(:code, :date, :sync_record)

  def generate_and_send_xml_document customer_number, data_315s, testing = false
    return if data_315s.nil? || data_315s.size == 0

    doc, root = build_xml_document "VfiTrack315s"
    counter = 0
    data_315s = Array.wrap(data_315s)
    data_315s.each do |data|
      write_315_xml root, customer_number, data
      counter += 1
    end

    if counter > 0
      Tempfile.open(["315-#{data_315s.first.datasource}-#{data_315s.first.broker_reference}-", ".xml"]) do |fout|
        # The FTP send and milestone updates all need to be done in one transaction to ensure all or nothing 
        ActiveRecord::Base.transaction do 
          doc.write fout
          fout.flush
          fout.rewind
          ftp_sync_file fout, data_315s.map {|d| d.sync_record }, folder: ftp_folder(customer_number, testing)

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

  def write_315_xml parent_element, customer_number, data
    root = add_element parent_element, "VfiTrack315"
    add_element root, "BrokerReference", data.broker_reference
    add_element root, "EntryNumber", data.entry_number
    add_element root, "CustomerNumber", customer_number
    add_element root, "ShipMode", data.ship_mode
    add_element root, "ServiceType", data.service_type
    add_element root, "CarrierCode", data.carrier_code
    add_element root, "Vessel", data.vessel
    # Voyage must be at least 2 chars to fit EDI document standards for the 315, so zero-pad the voyage to 2 chars
    add_element root, "VoyageNumber", data.voyage_number.to_s.rjust(2, "0")
    add_element root, "PortOfEntry", data.port_of_entry
    add_element root, "PortOfLading", data.port_of_lading
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

  def process_field field, user, entry, testing, additional_fingerprint_values = []
    mf = ModelField.find_by_uid field[:model_field_uid]
    value = mf.process_export entry, user, true

    # Do nothing if there's no value..we don't bother sending blanked time fields..
    milestone = nil
    if value
      timezone = field[:timezone].blank? ? default_timezone : ActiveSupport::TimeZone[field[:timezone]]
      no_time = field[:no_time].to_s.to_boolean
      updated_date = adjust_date_time(value, timezone, no_time)
      code = event_code mf.uid

      mu = MilestoneUpdate.new(code, updated_date)

      # If we're testing...we're going to send files all the time, regardless over whether the data is changed or not
      # Testing setups should be limited by search criterions to a single file (or small range of files), so this shouldn't
      # matter.
      if testing
        milestone = mu
      else
        fingerprint = calculate_315_fingerprint(mu, additional_fingerprint_values)

        sync_record = entry.sync_records.where(trading_partner: "315_#{code}").first_or_initialize

        # If the confirmed at time nil it means the record wasn't actually sent (maybe generation failed), in which case,
        # if it's been over 5 minutes since it was last sent, then try sending again.
        if sync_record.fingerprint != fingerprint || sync_record.sent_at.nil? || (sync_record.confirmed_at.nil? && (sync_record.sent_at > Time.zone.now - 5.minutes))
          sync_record.fingerprint = fingerprint
          # We're sort of abusing the sync record's confirmed at here so that we can do two-phase generating / sending
          # Confirmed at is sent once we've confirmed the record has actually been sent (ftp'ed)
          sync_record.sent_at = Time.zone.now
          sync_record.confirmed_at = nil

          sync_record.save!
          mu.sync_record = sync_record

          milestone = mu
        end
      end
    end
    milestone
  end

  def adjust_date_time value, timezone, no_time
    # If the value's already a date, there's nothing to do here...
    if value.respond_to?(:acts_like_time?) && value.acts_like_time?
      # Change to the specified timezone, then change to date if required
      # Using strftime here specifically so we also drop seconds (if they're there, since 
      # we're not sending out seconds in the 315, we don't want our comparison with what 
      # was sent to include seconds either).

      # I'm sure this is a total hack, but I coudln't find another more direct way to zero out
      # any seconds / milliseconds values and then convert to a destination timezone
      base_tz = ActiveSupport::TimeZone["UTC"]
      value = base_tz.parse(value.in_time_zone(base_tz).strftime("%Y-%m-%d %H:%M")).in_time_zone timezone
      value = value.to_date if no_time
    end

    value
  end
  
  def xref_date_value date
    date.iso8601
  end

  def default_timezone
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  def v uid, obj
    ModelField.find_by_uid(uid).process_export obj, user
  end

  def user
    @user ||= User.integration
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

  def event_code uid
    # Just trim the "ent_" of the front of the uids and use as the event code
    uid.to_s.sub /^[^_]+_/, ""
  end

  def calculate_315_fingerprint milestone, finger_print_fields
    values = [milestone.code, xref_date_value(milestone.date)]
    values.push *finger_print_fields

    Digest::SHA1.hexdigest values.join("~*~")
  end


  def fingerprint_field_data obj, user, setup
    # Sort the fields by name (so order doesn't play into the fingerprint) and eliminate any duplicates.
    Array.wrap(setup.fingerprint_fields).sort.uniq.map {|f| ModelField.find_by_uid(f).process_export(obj, user, true)}.map do |v|
      v = if v.respond_to?(:blank?)
        v.blank? ? "" : v
      else
        v
      end

      v.respond_to?(:strip) ? v.strip : v
    end
  end

end; end; end;