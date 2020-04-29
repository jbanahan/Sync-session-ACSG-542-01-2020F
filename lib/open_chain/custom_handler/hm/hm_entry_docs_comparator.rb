require 'open_chain/custom_handler/vandegrift/kewill_entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Hm; class HmEntryDocsComparator
  extend OpenChain::CustomHandler::Vandegrift::KewillEntryComparator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.accept? snapshot
    accept = super
    if accept
      # This should not run for entries exported from CA, those are returns from online sales and we don't need to populate products with that data.
      accept = snapshot.recordable.try(:customer_number).to_s.upcase == "HENNE" && snapshot.recordable.try(:export_country_codes).to_s.upcase != "CA"
    end

    accept
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(old_bucket, old_path, old_version, new_bucket, new_path, new_version)
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_part_number])
  end

  def importer
    @importer ||= begin
      i = Company.importers.where(system_code: "HENNE").first
      raise "No H&M Importer account could be found." unless i
      i
    end

    @importer
  end

  def sync_record entry
    sr = entry.sync_records.find {|sr| sr.trading_partner == "H&M Docs"}
    sr = entry.sync_records.build(trading_partner: "H&M Docs") if sr.nil?

    sr
  end

  def newest_attachment attachments
    attachments.sort_by {|a| mf(a, :att_updated_at) }.first
  end

  def compare old_bucket, old_path, old_version, new_bucket, new_path, new_version
    new_json = get_json_hash(new_bucket, new_path, new_version)

    # Don't run unless there are broker invoices
    return unless json_child_entities(new_json, "BrokerInvoice").length > 0

    # Don't run unless there's entry packets
    newest_packet = newest_attachment(entry_packets(new_json))
    return unless newest_packet.present?

    entry = find_entity_object(new_json)
    return unless entry

    sr = sync_record(entry)
    attachment_updated_at = mf(newest_packet, :att_updated_at)

    return unless sr.sent_at.nil? || attachment_updated_at > sr.sent_at

    attachment = find_entity_object(newest_packet)
    # Attachment could be nil if it was deleted in the intervening time that this comparator was sitting in the job queue
    return if attachment.nil?

    product_packet_filename = "Entry Packet - #{entry.broker_reference}.pdf"
    part_data = extract_part_data(new_json)

    user = User.integration

    attachment.download_to_tempfile do |tempfile|
      Attachment.add_original_filename_method(tempfile, product_packet_filename)

      part_data.each do |part|

        find_or_create_product(part, user, entry) do |product|
          added_attachment = false

          if !product_has_attachment?(product, product_packet_filename, "Entry Packet", attachment.attached_file_size)

            new_attachment = product.attachments.create! attached: tempfile, attachment_type: "Entry Packet"
            # Remove any other "Entry Packet" attachments named the same thing that might be on the product
            product.attachments.each do |a|
              a.destroy if a.attachment_type.to_s.upcase == "ENTRY PACKET" && a.attached_file_name == product_packet_filename && new_attachment.id != a.id
            end

            added_attachment = true
          end

          added_attachment
        end

        # The attachment create reads the tempfile, so rewind it so it can be re-used if there
        # are more products to associate this entry packet with
        tempfile.rewind
      end
    end

    sr.sent_at = Time.zone.now
    sr.confirmed_at = (Time.zone.now + 1.minute)
    sr.save!

  end

  def entry_packets json
    packets = []
    json_child_entities(json, "Attachment").each do |att|
      next unless mf(att, 'att_attachment_type').to_s.upcase == "ENTRY PACKET"

      packets << att
    end
    packets
  end

  def product_has_attachment? product, attachment_name, attachment_type, attached_file_size
    !product.attachments.find {|a| a.attached_file_name == attachment_name && a.attachment_type == attachment_type && a.attached_file_size == attached_file_size}.nil?
  end

  def extract_part_data json
    part_data = []

    json_child_entities(json, "CommercialInvoice").each do |invoice|
      json_child_entities(invoice, 'CommercialInvoiceLine').each do |line|
        part_data << {part_number: mf(line, :cil_part_number), importer_id: importer.id}
      end
    end

    part_data
  end


  def find_or_create_product part_data, user, entry
    # Return nil if any of the part data is blank, technically, there should be a business rule blocking
    # these from even making it to this point, but the rule cuts off semi-recently and some really old
    # HM entries are getting updated still.
    return nil if part_data[:part_number].blank? || part_data[:importer_id].blank?

    product = nil
    unique_id = "HENNE-#{part_data[:part_number]}"

    created = false
    classification_added = false
    Lock.acquire("Product-#{unique_id}") do
      product = Product.where(unique_identifier: unique_id, importer_id: part_data[:importer_id]).first
      # This is a bit of a microoptimization...we don't set the custom definition for part number unless we're creating the product
      # The field should never be something other than the unique identifier so this should work fine
      if product.nil?
        product = Product.new unique_identifier: unique_id, importer_id: part_data[:importer_id]
        product.find_and_set_custom_value cdefs[:prod_part_number], part_data[:part_number]
        product.save!
        created = true
      end
    end

    Lock.with_lock_retry(product) do
      updated = yield product

      product.create_snapshot user, nil, "H&M Entry Docs" if updated || created
    end
    nil
  end

end; end; end; end
