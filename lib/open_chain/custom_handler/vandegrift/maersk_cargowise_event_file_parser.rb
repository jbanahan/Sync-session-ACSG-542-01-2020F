require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/nokogiri_xml_helper'

module OpenChain; module CustomHandler; module Vandegrift; class MaerskCargowiseEventFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::NokogiriXmlHelper

  def self.integration_folder
    ["#{MasterSetup.get.system_code}/maersk_cw_universal_event"]
  end

  def self.parse_file data, log, opts={}
    doc = Nokogiri::XML(data)
    # Eliminate namespaces from the document.  If this is not done, the xpath xpressions need to be namespaced.
    # # Since there's only a single namespace in these CW documents, there's no harm in tossing it.
    doc.remove_namespaces!
    self.new.parse(doc, opts)
  end


  def parse doc, opts={}
    # Root varies depending on how the XML is exported.  Dump UniversalInterchange/Body from the structure if it's included.
    if doc.root.name == 'UniversalInterchange'
      doc = doc.xpath "UniversalInterchange/Body"
    end

    broker_reference = first_text doc, "UniversalEvent/Event/DataContext/DataSourceCollection/DataSource[Type='CustomsDeclaration']/Key"
    if broker_reference.blank?
      inbound_file.add_reject_message "Broker Reference (Job Number) is required."
      return
    end
    inbound_file.add_identifier :broker_reference, broker_reference

    entry = nil
    Lock.acquire("Entry-Maersk-#{broker_reference}") do
      entry = Entry.where(broker_reference:broker_reference, source_system:Entry::CARGOWISE_SOURCE_SYSTEM).first_or_create! do |ent|
        inbound_file.add_info_message "Cargowise-sourced entry matching Broker Reference '#{broker_reference}' was not found, so a new entry was created."
      end
    end
    Lock.with_lock_retry(entry) do
      inbound_file.set_identifier_module_info :broker_reference, Entry, entry.id

      # This element can't be nil because we've already verified broker_reference is not nil.  That comes from
      # within the Event.
      elem_event = doc.xpath("UniversalEvent/Event").first
      event_type = et elem_event, "EventType"
      if event_type.present?
        event_reference = et elem_event, "EventReference"
        inbound_file.add_identifier :event_type, event_description(event_type, event_reference)
        event_date = parse_datetime(et elem_event, "EventTime")
        if set_event_info entry, event_date, event_type, event_reference
          add_entry_comment entry, event_date, event_type, event_reference

          entry.save!
          entry.create_snapshot User.integration, nil, opts[:key]
          entry.broadcast_event(:save)
          inbound_file.add_info_message "Event successfully processed."
        else
          inbound_file.add_info_message "No changes made."
        end
      else
        inbound_file.add_reject_message "Event Type is required."
      end
    end
  end

  private

    def event_description event_type, event_reference
      # Including the event_reference for some event types because it's used in conditional logic there.
      "#{event_type}#{event_reference && ['MSC','CES','MRJ'].include?(event_type) ? " | #{event_reference}" : ""}"
    end

    def parse_datetime date_str
      date_str.present? ? time_zone.parse(date_str) : nil
    end

    def time_zone
      # All times provided in the document are assumed to be from this zone.
      @zone ||= ActiveSupport::TimeZone["America/New_York"]
    end

    def parse_boolean bool_str
      bool_str.try(:downcase) == "true"
    end

    def set_event_info entry, event_date, event_type, event_reference
      date_set = true
      if event_type == 'CCC'
        entry.entry_filed_date = event_date
        set_first_occurrence_date entry, :first_entry_sent_date, event_date
        entry.across_sent_date = event_date
      elsif event_type == 'MSC'
        if /SO\s*-\s*PGA\s+(-\s*)?(?<agency_code>\S+)\s+(?<disposition_code>\d+)/ =~ event_reference
          if agency_code == "FDA"
            date_1_set = set_first_occurrence_date entry, :fda_transmit_date, event_date
            date_2_set, date_3_set, date_4_set = [false]*4
            if disposition_code == "01"
              date_2_set = set_first_occurrence_date entry, :fda_review_date, event_date
            elsif disposition_code == "02"
              date_3_set = set_first_occurrence_date entry, :fda_hold_date, event_date
            elsif disposition_code == "07"
              entry.fda_release_date = event_date
              entry.fda_hold_release_date = event_date
              date_4_set = true
            end
            date_set = date_1_set || date_2_set || date_3_set || date_4_set
          elsif agency_code == "NHT"
            if disposition_code == "02"
              date_set = set_first_occurrence_date entry, :nhtsa_hold_date, event_date
            elsif disposition_code == "07"
              date_set = set_first_occurrence_date entry, :nhtsa_hold_release_date, event_date
            end
          elsif agency_code == "NMF"
            if disposition_code == "02"
              date_set = set_first_occurrence_date entry, :nmfs_hold_date, event_date
            elsif disposition_code == "07"
              date_set = set_first_occurrence_date entry, :nmfs_hold_release_date, event_date
            end
          else
            if disposition_code == "02"
              date_set = set_first_occurrence_date entry, :other_agency_hold_date, event_date
            elsif disposition_code == "07"
              date_set = set_first_occurrence_date entry, :other_agency_hold_release_date, event_date
            end
          end
        elsif event_reference&.include?("AX")
          entry.first_entry_sent_date = event_date
          date_set = true
        else
          date_set = false
        end
      elsif event_type == 'CLR'
        date_1_set, date_2_set, date_3_set = [false]*3
        date_1_set = set_first_occurrence_date entry, :first_release_received_date, event_date
        date_2_set = set_first_occurrence_date entry, :pars_ack_date, event_date
        date_3_set = set_first_occurrence_date entry, :across_declaration_accepted, event_date
        date_4_set = set_first_occurrence_date entry, :first_7501_print, event_date
        date_set = date_1_set || date_2_set || date_3_set || date_4_set
      elsif event_type == 'DIM'
        entry.edi_received_date = event_date&.to_date
      elsif event_type == 'JOP'
        entry.file_logged_date = event_date
      elsif event_type  == 'DDV'
        entry.last_7501_print = event_date
        if event_reference&.include? "Delivery Order"
          set_first_occurrence_date entry, :first_do_issued_date, event_date
        end
      elsif event_type == 'CRP'
        entry.cadex_accept_date = event_date
        event_date_plus_one = event_date ? event_date.to_date + 1.day : nil
        entry.k84_receive_date = event_date_plus_one
        entry.b3_print_date = event_date_plus_one
      elsif event_type == 'CES'
        date_1_set, date_2_set, date_3_set = [false]*3
        if event_reference&.include?("EXM")
          date_1_set = set_first_occurrence_date entry, :exam_ordered_date, event_date
        elsif event_reference == 'WTA'
          date_2_set = set_first_occurrence_date entry, :pars_ack_date, event_date
          date_3_set = set_first_occurrence_date entry, :across_declaration_accepted, event_date
        end
        date_set = date_1_set || date_2_set || date_3_set
      elsif event_type == 'MRJ'
        if event_reference == "IID REJECTED"
          entry.pars_reject_date = event_date
        else
          date_set = false
        end
      else
        inbound_file.add_warning_message "Event Type is not mapped and was ignored: #{event_type}."
        date_set = false
      end
      date_set
    end

    # Setting date field value only if it doesn't already have a value, or if it contains a later date than the
    # new date value.  Returns true only under these conditions as well.
    def set_first_occurrence_date entry, date_field, event_date
      date_set = false
      if entry.try(date_field).nil? || (event_date && entry.try(date_field) > event_date)
        entry.send((date_field.to_s + "=").to_sym, event_date)
        date_set = true
      end
      date_set
    end

    # Entry updates are written to entry comments for some reason.
    def add_entry_comment entry, event_date, event_type, event_reference
      username = "UniversalEvent"
      event_date_formatted = event_date.present? ? event_date.strftime("%Y-%m-%d %H:%M:%S") : "(no date)"
      body = "#{event_date_formatted} - #{event_type} - #{event_reference}"

      # Look for this comment within the entry, adding it only if it doesn't already exist.  There's no better
      # way to do this check than by comment content, unfortunately.
      if entry.entry_comments.find { |comm| comm.username == username && comm.body == body }.nil?
        comment = entry.entry_comments.build
        comment.body = body
        comment.username = username
        comment.public_comment = false
        comment.generated_at = event_date
      end
      nil
    end

end; end; end; end