require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/nokogiri_xml_helper'

module OpenChain; module CustomHandler; module Vandegrift; class MaerskCargowiseEventFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::NokogiriXmlHelper

  def self.integration_folder
    ["#{MasterSetup.get.system_code}/maersk_cw_universal_event"]
  end

  def self.parse_file data, log, opts={}
    self.new.parse(xml_document(data), opts)
  end

  def parse doc, opts={}
    # Root varies depending on how the XML is exported.  Dump UniversalInterchange/Body from the structure if it's included.
    if doc.root.name == 'UniversalInterchange'
      doc = xpath(doc, "UniversalInterchange/Body").first
    end

    broker_reference = extract_job_number(doc)
    if broker_reference.blank?
      inbound_file.add_reject_message "Broker Reference (Job Number) is required."
      return
    end
    inbound_file.add_identifier :broker_reference, broker_reference

    entry = nil
    
    Lock.acquire("Entry-#{broker_reference}") do
      entry = Entry.where(broker_reference:broker_reference, source_system:Entry::CARGOWISE_SOURCE_SYSTEM).first_or_create! do |ent|
        inbound_file.add_info_message "Cargowise-sourced entry matching Broker Reference '#{broker_reference}' was not found, so a new entry was created."
      end
    end

    Lock.db_lock(entry) do
      inbound_file.set_identifier_module_info :broker_reference, Entry, entry.id

      event_processed = process_event(entry, doc)
      documents_processed = process_documents(entry, doc)

      if event_processed || documents_processed
        entry.create_snapshot User.integration, nil, opts[:key]
        entry.broadcast_event(:save)
      else
        inbound_file.add_info_message "No changes made."
      end
    end
  end

  def process_event entry, doc
    entry_updated = false
    # This element can't be nil because we've already verified broker_reference is not nil.  That comes from
    # within the Event.
    elem_event = xpath(doc, "UniversalEvent/Event").first
    event_type = et elem_event, "EventType"
    if event_type.present?
      event_reference = et elem_event, "EventReference"
      inbound_file.add_identifier :event_type, event_description(event_type, event_reference)
      event_date = parse_datetime(et elem_event, "EventTime")
      if set_event_info entry, event_date, event_type, event_reference
        add_entry_comment entry, event_date, event_type, event_reference
        entry_updated = true
        entry.save!
        inbound_file.add_info_message "Event successfully processed."
      end
    else
      inbound_file.add_reject_message "Event Type is required."
    end

    entry_updated
  end

  def process_documents entry, doc
    documents_attached = []

    xpath(doc, "UniversalEvent/Event/AttachedDocumentCollection/AttachedDocument") do |element|
      attached = process_document(entry, element)
      documents_attached = true if attached
    end

    documents_attached
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

      # We're not processing events for DDA - Documents Attached...the document handler 
      # will deal with this.
      return false if event_type == 'DDA'

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
        entry.k84_receive_date = event_date
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

    def process_document entry, element
      document_bytes = document_data element
      return false unless document_bytes && document_bytes.length > 0

      # We're going to use a SHA256 hash of the document_bytes as the checksum to determine, along
      # with the filename and attachment type if have already received the document or not.
      checksum = document_checksum(document_bytes)
      attachment_type = document_attachment_type(element)
      filename = document_filename element      

      inbound_file.add_identifier :attachment_name, filename

      if document_already_received?(entry, checksum, filename, attachment_type)
        inbound_file.add_info_message "Document '#{filename}' is already attached to this entry."
        return false
      end

      attachment = entry.attachments.build checksum: checksum, attachment_type: attachment_type
      attachment.source_system_timestamp = document_timestamp(element)
      attachment.is_private = document_private?(element)
      
      io = StringIOAttachment.new(document_bytes)
      io.original_filename = filename

      attachment.attached = io
      
      attachment.save!

      if remove_previous_documents_for_type?(attachment_type)
        remove_other_documents(entry, attachment)
      end

      inbound_file.add_info_message "Attached document #{filename}."
      return true
    end

    def document_filename element
      *, filename = split_filename(base_filename(element))

      # The filename puts slashes (/) in as date separators...which we don't want since that's an invalid linux character
      Attachment.get_sanitized_filename(filename.gsub(/[\/:]/, "-"))
    end

    def document_attachment_type element
      type_code = document_type_code(element)

      if origin_document?(type_code)
        return "Origin Document Pack"
      else
        filename = base_filename(element)
        cust_code, document_type, * = split_filename(filename)

        # We might have to add a cross reference at some point to turn the CW type codes into the VFI Track ones.
        # At this point, we're not going to be doing that.
        type_code = document_type unless document_type.blank?
      end

      type_code
    end

    # Returns an array where the first element is the customer code,
    # second element is the document type and the third element
    # is the actual filename to utilize
    def split_filename filename
      # Most filenames should look like the following: TC4-3461-BQMJ00419059035-20190804150932.pdf
      # TC4 is the customer code
      # 3461 is the document type
      # BQMJ00419059035 is the job number
      # 20190804150932 is a timestamp
      if filename =~ /([^-]+)-([^-]+)-(.*)/i
        return [$1, $2, $3]
      else
        return [nil, nil, filename]
      end
    end

    def document_type_code element
      et(element, "Type/Code").to_s.strip
    end

    def origin_document? type_code
      type_code.to_s.upcase == "ORG"
    end

    def base_filename element
      filename = et(element, "FileName").to_s
      # The document filename given in the xml is REALLY long and looks like it contains the company name / code
      # of the broker in it.  We want to try and strip that out.
      if filename.starts_with?("Damco Customs Services Inc. - 004 DAMCO CUSTOMS SERVICES INC - ")
        filename = filename.sub("Damco Customs Services Inc. - 004 DAMCO CUSTOMS SERVICES INC - ", "")
      end

      filename
    end

    def remove_previous_documents_for_type? document_type
      DataCrossReference.keys(DataCrossReference::CARGOWISE_SINGLE_DOCUMENT_CODE).include? document_type
    end

    def remove_other_documents entry, newest_attachment
      entry.attachments.where(attachment_type: newest_attachment.attachment_type).where("id <> ?", newest_attachment.id).destroy_all
    end

    def document_timestamp element
      ActiveSupport::TimeZone["UTC"].parse(et(element, "SaveDateUTC")) rescue nil
    end

    def document_private? element
      et(element, "IsPublished").to_s.strip.downcase != "true"
    end

    def document_data element
      image_data = et(element, "ImageData")
      return nil if image_data.blank?
      Base64.decode64(image_data)
    end

    def document_checksum document_data
      Digest::SHA256.hexdigest(document_data)
    end

    def document_already_received? entry, checksum, filename, attachment_type
      entry.attachments.find_all { |d| d.checksum == checksum && d.attached_file_name == filename && d.attachment_type == attachment_type }.length > 0
    end

    def extract_job_number doc
      broker_reference = extract_standard_job_number(doc)
      if broker_reference.blank?
        broker_reference = extract_job_number_from_document_file_name(doc)
      end

      broker_reference
    end

    def extract_standard_job_number doc
      first_text doc, "UniversalEvent/Event/DataContext/DataSourceCollection/DataSource[Type='CustomsDeclaration']/Key"
    end

    def extract_job_number_from_document_file_name doc
      job_number = nil
      element = xpath(doc, "UniversalEvent/Event/AttachedDocumentCollection/AttachedDocument").first
      file_name = base_filename(element)
      if !file_name.blank?
        cust_code, document_type, actual_filename = split_filename(file_name)
        if !actual_filename.blank?
          # At this point the filename should look like BQMJ00419057999-19070514444100384519.pdf.
          # The BQMJ portion is the job number we're after.
          if actual_filename =~ /\A([^-]+)-.+\z/
            job_number = $1
          end
        end
      end

      job_number
    end

end; end; end; end