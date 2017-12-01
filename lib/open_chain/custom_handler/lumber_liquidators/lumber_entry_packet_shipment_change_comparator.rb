require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/shipment_comparator'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberEntryPacketShipmentChangeComparator
  extend OpenChain::EntityCompare::ShipmentComparator
  include OpenChain::EntityCompare::ComparatorHelper

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(id, new_bucket, new_path, new_version)
  end

  def compare id, new_bucket, new_path, new_version
    new_json = get_json_hash(new_bucket, new_path, new_version)
    ods_attachment, vds_attachment = get_entry_packet_components new_json

    # Proceed only if the shipment has both attachment flavors.  These are required to generate an entry packet.
    if ods_attachment.present? && vds_attachment.present?
      shipment = Shipment.where(id: id).first
      if shipment
        Lock.with_lock_retry(shipment) do
          sr = shipment.sync_records.where(trading_partner: "Entry Packet").first_or_initialize
          # If there's no sent at date in the sync record (which will be the case for a new record or one blanked via
          # the screen to force a send) or one of the attachments was updated more recently than the sync record's
          # sent at date, generate an entry packet.
          if sr.sent_at.nil? || ods_attachment.attached_updated_at > sr.sent_at || vds_attachment.attached_updated_at > sr.sent_at
            make_entry_packet(ods_attachment, vds_attachment) do |entry_packet_pdf|
              attach_entry_packet_to_entry shipment, entry_packet_pdf, sr.persisted?
            end

            # The sync record is updated even if the entry packet couldn't be attached to an entry and had to be
            # emailed to ops instead.  The sync record's meaning is more that the comparator "did something" rather
            # than that everything walked the happy path.
            sr.sent_at = Time.zone.now
            sr.confirmed_at = (sr.sent_at + 1.minute)
            sr.save!
          end
        end
      end
    end
  end

  private
    # Returns an array of ODS (Forwarder Ocean Document Set) and VDS (Vendor Document Set) components of an entry
    # packet, with ODS sorted first (as is supposed to be the case in the entry packet itself).  Both components must
    # be present to generate an entry packet.  VDS attachments are manually added to shipments by vendors using the
    # vendor portal.  ODS attachments come in via the LumberShipmentAttachmentFileParser.
    def get_entry_packet_components json
      ods_component = nil
      vds_component = nil
      json_child_entities(json, "Attachment").each do |att|
        attachment_type = mf(att, 'att_attachment_type').to_s
        case attachment_type
          when 'ODS-Forwarder Ocean Document Set'
            ods_component = find_entity_object(att)
          when 'VDS-Vendor Document Set'
            vds_component = find_entity_object(att)
        end
      end
      [ods_component, vds_component]
    end

    # Combines ODS (Forwarder Ocean Document Set) and VDS (Vendor Document Set) content to one PDF, called an entry
    # packet.  ODS file content is supposed to come before the VDS within the packet.
    def make_entry_packet ods_pdf_attachment, vds_pdf_attachment
      entry_packet_pdf = CombinePDF.new

      add_attachment_pdf_to_entry_packet ods_pdf_attachment, entry_packet_pdf
      add_attachment_pdf_to_entry_packet vds_pdf_attachment, entry_packet_pdf

      # Write the PDF to a temp file and work with that inside a block (so temp is automatically cleaned up).
      Tempfile.open('EntryPacket - LUMBER.pdf') do |tmp|
        tmp.binmode
        entry_packet_pdf.save(tmp.path)
        yield tmp
      end
    end

    def add_attachment_pdf_to_entry_packet pdf_attachment, entry_packet_pdf
      pdf_attachment.download_to_tempfile do |pdf_temp_file|
        # Eat useless warning messages (e.g. "PDF 1.5 Object streams found - they are not fully supported! attempting
        # to extract objects.") to prevent them from filling up the log.
        Kernel.silence_warnings do
          entry_packet_pdf << CombinePDF.load(pdf_temp_file.path, allow_optional_content: true)
        end
      end
    end

    def attach_entry_packet_to_entry shp, entry_packet_pdf, revised
      ent = find_matching_entry shp
      if ent.present?
        # Entry packets aren't attached directly to the entry from this parser.  We have another process that does
        # that, one that filters through Kewill and updates multiple systems: ours and Lumber's.
        OpenChain::GoogleDrive.upload_file "US Entry Documents/Entry Packet/#{ent.broker_reference} - LUMBER.pdf", entry_packet_pdf
        generate_entry_packet_success_email shp, ent, revised
      else
        # The normal filename includes the broker reference, but since we don't know it (no entry), a default value
        # has to be assigned.
        Attachment.add_original_filename_method entry_packet_pdf, 'EntryPacket - LUMBER.pdf'
        generate_missing_entry_email shp, entry_packet_pdf
      end
    end

    def find_matching_entry shp
      Entry.where("master_bills_of_lading LIKE ? AND customer_references LIKE ?", "%#{shp.master_bill_of_lading}%", "%#{shp.reference}%").where(source_system: Entry::KEWILL_SOURCE_SYSTEM).first
    end

    def generate_entry_packet_success_email shp, entry, revised
      body_text = "#{(revised ? 'Revised d' : 'D')}ocs for master bill '#{shp.master_bill_of_lading}' / shipment reference '#{shp.reference}' have been transfered to entry '#{entry.broker_reference}'."
      OpenMailer.send_simple_html('LL-US@vandegriftinc.com', "Allport Entry Doc Success: #{shp.master_bill_of_lading} / #{shp.reference} / #{entry.broker_reference}", body_text).deliver!
    end

    def generate_missing_entry_email shp, entry_packet_pdf
      body_text = "No entry could be found for master bill '#{shp.master_bill_of_lading}' / shipment reference '#{shp.reference}'.  Once the entry has been opened, the attached Entry Packet document must be attached to it."
      OpenMailer.send_simple_html('LL-US@vandegriftinc.com', "Allport Missing Entry: #{shp.master_bill_of_lading} / #{shp.reference}", body_text, [entry_packet_pdf]).deliver!
    end

end; end; end; end