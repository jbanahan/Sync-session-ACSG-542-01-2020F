require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; class Generic315Generator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  MilestoneUpdate = Struct.new(:code, :date)

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
    # Our first customer using this feed requires sending distinct 315's for each combination of entry/mbol/container #
    # I'm anticipating this not being a global requirement, so I'm still preserving the ability to send multiple
    # mbols and containers per file.
    split_entries = split_entry_data_identifiers output_style, entry
    doc, root = build_xml_document "VfiTrack315s"
    counter = 0
    split_entries.each do |data|
      milestones.each do |milestone|
        generate root, entry, milestone.code, milestone.date, data[:master_bills], data[:container_numbers]
        counter += 1
      end
    end

    if counter > 0
      Tempfile.open(["315-#{entry.broker_reference}-", ".xml"]) do |fout|
        # The FTP send and milestone updates all need to be done in one transaction to ensure all or nothing 
        ActiveRecord::Base.transaction do 
          doc.write fout
          fout.flush
          fout.rewind
          ftp_file fout, folder: ftp_folder(entry.customer_number, testing)

          unless testing
            milestones.each do |milestone|
              DataCrossReference.create_315_milestone! entry, milestone.code, xref_date_value(milestone.date)
            end
          end
        end
      end
    end
   
    nil
  end

  def generate parent, entry, date_code, date, master_bills, container_numbers
    root = add_element parent, "VfiTrack315"
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
    add_element root, "CargoControlNumber", v(:ent_cargo_control_number, entry)

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

  protected
    
    def default_timezone
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def process_field field, user, entry
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
          return MilestoneUpdate.new(code, updated_date)
        end
      end
      nil
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
      elsif output_style == MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
        values = master_bills.map {|mb| {master_bills: [mb], container_numbers: containers}}
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
        # Since we can now potentially have multiple configs per customer (since you can have different statuses on the setups),
        # we need to collect all of them that are enabled.
        h[k] = MilestoneNotificationConfig.where(customer_number: k, enabled: true).order(:id).all
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