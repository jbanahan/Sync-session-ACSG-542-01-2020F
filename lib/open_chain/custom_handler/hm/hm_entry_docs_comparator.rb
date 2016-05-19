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
      accept = snapshot.recordable.try(:customer_number).to_s.upcase == "HENNE"
    end

    accept
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(old_bucket, old_path, old_version, new_bucket, new_path, new_version)
  end


  def initialize
    @cdefs = self.class.prep_custom_definitions([:prod_part_number, :prod_value_order_number, :prod_value])
  end


  def compare old_bucket, old_path, old_version, new_bucket, new_path, new_version
    new_json = get_json_hash(new_bucket, new_path, new_version)
    new_entry_packets = entry_packets(new_json)

    if new_entry_packets.length > 0
      entry = find_entity_object(new_json)
      return unless entry

      # We need to evaluate business rules for entries before we continue.
      BusinessValidationTemplate.create_results_for_object! entry

      entry.reload
      return unless entry.failed_business_rules.blank?

      user = User.integration
      products = []
      extract_part_data(new_json).each do |data|
        products << find_or_create_product(data, user)
      end

      # Now see if we need to move any packets over...only move them the if products
      # don't have the entry packets.

      # Now attach all the new packets to the products we found
      new_entry_packets.each do |packet|
        attachment = find_entity_object(packet)
        # Attachment could be nil if it was deleted in the intervening time that this comparator was sitting in the job queue
        next if attachment.nil? 

        filename = "Entry Packet - #{entry.broker_reference} - #{attachment.attached_file_name}"
        products_to_attach = products_need_attachment(products, filename, "Entry Packet", attachment.attached_file_size)

        if products_to_attach.length > 0
          attachment.download_to_tempfile do |tempfile|
            Attachment.add_original_filename_method(tempfile, filename)

            products_to_attach.each do |product|
              Product.transaction do
                new_attachment = product.attachments.create! attached: tempfile, attachment_type: "Entry Packet"

                # Remove any other "Entry Packet" attachments named the same thing that might be on the product
                product.attachments.each do |a|
                  a.destroy if a.attachment_type.to_s.upcase == "ENTRY PACKET" && a.attached_file_name == filename && new_attachment.id != a.id
                end
              end
              
              # The attachment create reads the tempfile, so rewind it so it can be re-used if there
              # are more products to associate this entry packet with
              tempfile.rewind
            end
          end
        end
      end
    end
  end

  def entry_packets json
    packets = []
    json_child_entities(json, "Attachment").each do |att|
      next unless mf(att, 'att_attachment_type').to_s.upcase == "ENTRY PACKET"

      packets << att
    end
    packets
  end

  def products_need_attachment products, attachment_name, attachment_type, attached_file_size
    products.reject {|p| p.attachments.where(attached_file_name: attachment_name, attachment_type: attachment_type, attached_file_size: attached_file_size).count > 0 }
  end

  def extract_part_data json
    part_data = []
    @importer ||= Company.importers.where(system_code: "HENNE").first
    raise "No H&M Importer account could be found." unless @importer

    json_child_entities(json, "CommercialInvoice").each do |invoice|
      po_number = mf(invoice, 'ci_invoice_number')
      json_child_entities(invoice, 'CommercialInvoiceLine').each do |line|
        part_no = mf(line, 'cil_part_number')
        data = {po_number: po_number, part_number: part_no, importer_id: @importer.id, tariffs: Set.new}
        json_child_entities(line, "CommercialInvoiceTariff").each do |tariff|
          hts = mf(tariff, 'cit_hts_code').to_s
          # Skip any tariff rows that are from chapter 98
          next if hts.starts_with?("98") || hts.blank?

          data[:tariffs] << hts.to_s.gsub(".", "")

          if data[:per_piece_value].nil?
            entered_value = BigDecimal.new(mf(tariff, 'cit_entered_value').to_s)
            pieces = BigDecimal.new(mf(line, 'cil_units').to_s)

            if pieces.nonzero?
              data[:per_piece_value] = (entered_value / pieces).round(2)
            end
          end
        end

        part_data << data
      end
    end
    part_data
  end


  def find_or_create_product part_data, user
    product = nil
    unique_id = "HENNE-#{part_data[:part_number]}"
    @us ||= Country.where(iso_code: "US").first
    raise "No US country found" unless @us

    created = false
    Lock.acquire("Product-#{unique_id}") do 
      product = Product.where(unique_identifier: unique_id, importer_id: part_data[:importer_id]).first
      # This is a bit of a microoptimization...we don't set the custom definition for part number unless we're creating the product
      # The field should never be something other than the unique identifier so this should work fine
      if product.nil?
        product = Product.new unique_identifier: unique_id, importer_id: part_data[:importer_id]
        product.find_and_set_custom_value @cdefs[:prod_part_number], part_data[:part_number]
        created = true
      end

      # Also set the US classification here always
      classification = product.classifications.find {|c| c.country_id == @us.id}
      if classification.nil?
        product.classifications.build country_id: @us.id
      end

      product.save! if product.changed?
    end

    Lock.with_lock_retry(product) do
      classification = product.classifications.find {|c| c.country_id == @us.id}

      tariff_saved = false
      part_data[:tariffs].each do |tariff|
        tariff = tariff.to_s.gsub(".", "")
        next if tariff.blank?

        tariff_record = classification.tariff_records.find {|t| t.hts_1.to_s == tariff}
        if tariff_record.nil?
          classification.tariff_records.create! hts_1: tariff
          tariff_saved = true
        end
      end

      po_updated = set_po_information product, part_data

      # I don't really know why product.changed? is not working here to detect when we build tariff records 
      # or add new custom values, but it's not, so I'm saving inline in those cases and using flags to determine if a 
      # save occurred to determine if we should snapshot or not.
      if created || tariff_saved || po_updated
        product.create_snapshot user
      end
    end
    
    product
  end


  def set_po_information product, part_data
    value_order_number = product.custom_value(@cdefs[:prod_value_order_number])
    product_value = product.custom_value(@cdefs[:prod_value])

    if value_order_number.blank? && !part_data[:po_number].blank? && !part_data[:per_piece_value].nil?
      product.update_custom_value!(@cdefs[:prod_value_order_number], part_data[:po_number])
      product.update_custom_value!(@cdefs[:prod_value], part_data[:per_piece_value])
      return true
    elsif !part_data[:po_number].blank? && !part_data[:prod_value].nil?
      # Compare the last digit of the order (strip any trailing non-digit data - they have alpha chars at the end of the PO's sometimes)
      # If the new one is a higher number than the old one, then we're using it's per piece value
      value_order_number = value_order_number.to_s.gsub(/\D+$/, "")
      new_value_order_number = part_data[:po_number].gsub(/\D+$/, "")

      if new_value_order_number[-1].to_i > value_order_number[-1].to_i
        product.update_custom_value!(@cdefs[:prod_value_order_number], part_data[:po_number])
        product.update_custom_value!(@cdefs[:prod_value], part_data[:per_piece_value])
        return true
      end
    end

    false
  end

end; end; end; end