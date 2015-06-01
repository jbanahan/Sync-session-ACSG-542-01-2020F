require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; class Generic315Generator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  def accepts? event, entry
    # Just check if the customer has a 315 setup, at this point..if so, then accept.  We'll decide in receive if we're actually generating anythign
    # or not.
    MasterSetup.get.custom_feature?("Entry 315") && !entry.customer_number.blank? && !setup_315(entry).nil?
  end

  def receive event, entry
    setup = setup_315(entry)
    matches = setup.search_criterions.collect {|sc| sc.test? entry}.uniq.compact
    user = User.integration
    if setup.search_criterions.length == 0 || (matches.length == 1 && matches[0] == true)
      setup.setup_json.each do |field|
        process_field field.with_indifferent_access, setup.output_style, user, entry
      end
    end
  end

  def generate_and_send_315 output_style, entry, code, date
    # Our first customer using this feed requires sending distinct 315's for each combination of entry/mbol/container #
    # I'm anticipating this not being a global requirement, so I'm still preserving the ability to send multiple
    # mbols and containers per file.
    split_entries = split_entry_data_identifiers output_style, entry

    split_entries.each do |data|
      xml = generate entry, code, date, data[:master_bills], data[:container_numbers]

      Tempfile.open(["#{entry.broker_reference}-#{data[:master_bills].first}-#{data[:container_numbers].first}-#{code}-", ".xml"]) do |fout|
        xml.write fout
        fout.rewind
        ftp_file fout
      end
    end

    DataCrossReference.create_315_milestone! entry, code, xref_date_value(date)
  end

  def generate entry, date_code, date, master_bills, container_numbers
    doc, root = build_xml_document "VfiTrack315"
    add_element root, "BrokerReference", v(:ent_brok_ref, entry)
    add_element root, "EntryNumber", v(:ent_entry_num, entry)
    add_element root, "CustomerNumber", v(:ent_cust_num, entry)
    add_element root, "ShipMode", v(:ent_transport_mode_code, entry)
    add_element root, "ServiceType", v(:ent_fcl_lcl, entry)
    add_element root, "CarrierCode", v(:ent_carrier_code, entry)
    add_element root, "Vessel", v(:ent_vessel, entry)
    add_element root, "VoyageNumber", v(:ent_voyage, entry)
    add_element root, "PortOfEntry", v(:ent_entry_port_code, entry)
    add_element root, "PortOfLading", v(:ent_lading_port_code, entry)

    add_collection_element root, "MasterBills", "MasterBill", master_bills
    add_collection_element root, "HouseBills", "HouseBill", v(:ent_hbols, entry)
    add_collection_element root, "Containers", "Container", container_numbers
    add_collection_element root, "PoNumbers", "PoNumber", v(:ent_po_numbers, entry)
    
    event = add_element root, "Event"
    add_element event, "EventCode", date_code
    add_element event, "EventDate", date.strftime("%Y%m%d")
    if date.respond_to?(:acts_like_time?) && date.acts_like_time?
      add_element event, "EventTime", date.strftime("%H%M")
    else
      add_element event, "EventTime", "0000"
    end

    doc
  end

  protected
    def ftp_credentials
      connect_vfitrack_net 'to_ecs/315'
    end

    def default_timezone
      ActiveSupport::TimeZone["UTC"]
    end

    def process_field field, output_style, user, entry
      mf = ModelField.find_by_uid field[:model_field_uid]
      value = mf.process_export entry, user, true

      # Do nothing if there's no value..we don't bother sending blanked time fields..
      if value
        timezone = field[:timezone].blank? ? default_timezone : ActiveSupport::TimeZone[field[:timezone]]
        no_time = field[:no_time].to_s.to_boolean
        updated_date = adjust_date_time(value, timezone, no_time)
        code = event_code mf.uid

        # Now check to see if this updated_date has already been sent out
        xref = DataCrossReference.find_315_milestone entry, code
        if xref.nil? || xref != xref_date_value(updated_date)
          generate_and_send_315 output_style, entry, code, updated_date
        end
      end
    end

  private 

    def split_entry_data_identifiers output_style, entry
      # We need to send distinct combinations of the broker reference / container / master bill
      # So if we have 2 containers and 2 master bills, then we end up sending 4 documents.
      master_bills = v(:ent_mbols, entry).to_s.split(/\n\s*/)
      containers = v(:ent_container_nums, entry).to_s.split(/\n\s*/)
      values = []
      if output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
        master_bills.each do |mb|
          if containers.length > 0
            containers.each {|c| values << {master_bills: [mb], container_numbers: [c]} }
          else
            values << {master_bills: [mb], container_numbers: [nil]}
          end
        end
        values = values.blank? ? [{master_bills: [nil], container_numbers: [nil]}] : values
      else
        values << {master_bills: master_bills, container_numbers: containers}
      end
      values
    end
  
    def v uid, entry
      ModelField.find_by_uid(uid).process_export entry, user
    end

    def user
      @user ||= User.integration
    end

    def add_collection_element parent, outer_el_name, inner_el_name, values
      el = add_element parent, outer_el_name
      vals = values.respond_to?(:to_a) ? values.to_a : values.to_s.split(/\n\s*/)
      vals.each do |v|
        next if v.blank?
        add_element el, inner_el_name, v
      end
      el
    end

    def setup_315 entry
      @cache ||= Hash.new do |h, k|
        config = MilestoneNotificationConfig.where(customer_number: k).first
        h[k] = (config.try(:enabled?) ? config : nil)
      end

      @cache[entry.customer_number]
    end

    def event_code uid
      # Just trim the "ent_" of the front of the uids and use as the event code
      uid.to_s.sub /^[^_]+_/, ""
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

end; end; end;