require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Ascena; class AscenaSupplementalFileParser
  include OpenChain::IntegrationClientParser

  def self.parse data, opts = {}
    self.new.parse data, opts
  end

  def parse data, opts = {}
    csv_data = CSV.parse(data).drop(1)
    ent_num = csv_data[0][21]&.gsub("-", "")
    if ent_num.blank?
      send_error "Entry Number", data, opts[:original_filename]
    elsif csv_data.any? { |row| row[55].blank? }
      send_error "PO Number", data, opts[:original_filename]
    else
      brok_ref = csv_data[1][21].split("-")[1]
      attach_to_entry ent_num, brok_ref, data, opts[:original_filename]
    end
  end

  def attach_to_entry ent_num, brok_ref, data, file_name
    find_or_create_entry(ent_num, brok_ref) do |entry|
      entry.attachments.find { |att| att.attachment_type == "FTZ Supplemental Data" }&.destroy
      attach_file data, file_name do |tempfile|
        entry.attachments.create! attached: tempfile, uploaded_by: User.integration, attachment_type: "FTZ Supplemental Data",
                                  attached_file_name: file_name
      end
      entry.save!
      entry.create_snapshot(User.integration, nil, inbound_file.s3_path)
    end
  end

  def send_error missing_field, data, file_name
    inbound_file.add_reject_message "#{missing_field}s are missing."
    to = MailingList.where(system_code: "ascena_ftz_validations").first || "support@vandegriftinc.com"
    attach_file data, file_name do |tempfile|
      body = "The Supplemental Data File #{file_name} was not processed due to missing #{missing_field}s. "\
             "Please add the correct #{missing_field}s to the Supplemental File and resend for processing."

      OpenMailer.send_simple_html(to, "Supplemental Data File was Rejected for Missing Data", body, tempfile).deliver_now
    end
  end

  private

  def attach_file data, file_name
    Tempfile.open(["suppl", ".csv"]) do |t|
      t << data
      t.flush
      Attachment.add_original_filename_method t, file_name

      yield t
    end
  end

  def find_or_create_entry ent_num, brok_ref
    entry = nil
    Lock.acquire("Entry-#{ent_num}") do
      entry = Entry.where(source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: brok_ref).first_or_create! entry_number: ent_num
    end

    Lock.db_lock(entry) { yield entry }
  end

end; end; end; end
