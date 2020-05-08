require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Ascena; class AscenaSupplementalFileParser
  include OpenChain::IntegrationClientParser

  def self.parse data, opts = {}
    csv_data = CSV.parse(data)
    ent_num = csv_data[1][21]&.gsub("-", "")
    raise "Entry number missing from supplemental file." unless ent_num
    brok_ref = csv_data[1][21].split("-")[1]

    find_or_create_entry(ent_num, brok_ref) do |entry|
      entry.attachments.find { |att| att.attachment_type == "FTZ Supplemental Data" }&.destroy
      # only modify fields for new entries
      attach_file entry, data, opts[:original_filename]
      entry.save!
      entry.create_snapshot(User.integration, nil, inbound_file.s3_path)
    end
  end

  def self.attach_file entry, data, file_name
    Tempfile.open(["suppl", ".csv"]) do |t|
      t << data
      t.flush
      entry.attachments.create! attached: t, uploaded_by: User.integration, attachment_type: "FTZ Supplemental Data",
                                attached_file_name: file_name
    end
  end

  private_class_method :attach_file

  def self.find_or_create_entry ent_num, brok_ref
    entry = nil
    Lock.acquire("Entry-#{ent_num}") do
      entry = Entry.where(source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: brok_ref).first_or_create! entry_number: ent_num
    end

    Lock.db_lock(entry) { yield entry }
  end

  private_class_method :find_or_create_entry

end; end; end; end
