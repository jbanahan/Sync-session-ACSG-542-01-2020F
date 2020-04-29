require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module CustomHandler; module Kirklands; class KirklandsEntryDutyFileGenerator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper

  KirklandsEntryData ||= Struct.new(:pay_to_id, :entry_number, :entry_filed_date, :vessel, :voyage, :export_date, :invoice_lines)
  KirklandsInvoiceLineData ||= Struct.new(:po_number, :part_number, :units, :tariff_lines)
  KirklandsTariffData ||= Struct.new(:hts_code, :duty_amount, :duty_code, :spi)

  SYNC_CODE ||= "KIRKLANDS_DUTY"

  def generate_and_send entry_snapshot
    entry_data = extract_xml_data(entry_snapshot)
    # If there's no invoice lines to send, then we don't actually have to do anything...this may be the case
    # when everything is duty free (or if something is just wacky with the entry data)
    if entry_data.invoice_lines.length > 0
      xml, filename = generate_xml(entry_data)
      entry = find_entity_object(entry_snapshot)
      send_xml(entry, xml, filename) unless entry.nil?
    end
  end

  def extract_xml_data entry_snapshot
    entry_data = extract_entry_data(entry_snapshot)

    json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine") do |invoice_line|
      line_data = extract_invoice_line_data(invoice_line)
      tariffs = extract_tariff_data_from_invoice_line(invoice_line)
      if tariffs.length > 0
        line_data.tariff_lines = tariffs
        entry_data.invoice_lines << line_data
      end
    end

    entry_data
  end

  def generate_xml entry_data
    doc, root = build_xml_document("CEMessage")
    now = Time.zone.now
    filename = create_filename(entry_data, now)

    add_transaction_info(root, filename, now)

    entry_data.invoice_lines.each do |invoice_line_data|
      invoice_line_data.tariff_lines.each do |invoice_tariff_data|
        add_ce_data(root, entry_data, invoice_line_data, invoice_tariff_data)
      end
    end

    [doc, filename]
  end

  private
    def send_xml entry, xml, filename
      Lock.db_lock(entry) do
        sr = entry.find_or_initialize_sync_record(SYNC_CODE)

        Tempfile.open([File.basename(filename, ".*"), ".xml"]) do |f|
          Attachment.add_original_filename_method f, filename
          write_xml xml, f
          f.rewind

          ftp_sync_file f, sr, ftp_data

          sr.sent_at = Time.zone.now
          sr.confirmed_at = (Time.zone.now + 1.minute)
          sr.save!
        end
      end
    end

    def ftp_data
      dir = MasterSetup.get.production? ? "kirklands_customs_entry_duty" : "kirklands_customs_entry_duty_test"
      connect_vfitrack_net("to_ecs/#{dir}")
    end

    def add_transaction_info parent, filename, now
      ti = add_element(parent, "TransactionInfo")
      add_element(ti, "Created", now.strftime("%Y%m%d"))
      add_element(ti, "FileName", filename)

      nil
    end

    def add_ce_data parent, entry_data, line_data, tariff_data
      ce = add_element(parent, "CEData")
      add_element(ce, "CustomEntryNo", entry_data.entry_number)
      add_element(ce, "EntryDate", entry_data.entry_filed_date.try(:strftime, "%m/%d/%Y"))
      add_element(ce, "PayToId", entry_data.pay_to_id)
      add_element(ce, "Vessel", entry_data.vessel)
      add_element(ce, "Voyage", entry_data.voyage)
      add_element(ce, "EstDepartDate", entry_data.export_date.try(:strftime, "%m/%d/%Y"))
      add_element(ce, "OrderNo", line_data.po_number)
      add_element(ce, "Item", line_data.part_number)
      add_element(ce, "ClearedQty", line_data.units)
      add_element(ce, "Hts", tariff_data.hts_code)
      add_element(ce, "CompId", tariff_data.duty_code)
      add_element(ce, "Amount", tariff_data.duty_amount)
      add_element(ce, "TariffTreatment", tariff_data.spi)
      nil
    end

    def create_filename entry_data, timestamp
      "CE_#{entry_data.entry_number}_#{timestamp.strftime("%Y%m%d%H%M%S%L")}.xml"
    end

    def extract_entry_data snapshot
      entry_data = KirklandsEntryData.new
      # Presumably this is the US Customs identifier for Kirklands to indicate they owed duty to USCBP
      entry_data.pay_to_id = "28432"
      entry_data.entry_number = mf(snapshot, :ent_entry_num)
      entry_data.entry_filed_date = mf(snapshot, :ent_filed_date)
      entry_data.vessel = mf(snapshot, :ent_vessel)
      entry_data.voyage = mf(snapshot, :ent_voyage)
      entry_data.export_date = mf(snapshot, :ent_export_date)
      entry_data.invoice_lines = []

      entry_data
    end

    def extract_invoice_line_data snapshot
      line_data = KirklandsInvoiceLineData.new
      line_data.po_number = mf(snapshot, :cil_po_number)
      line_data.part_number = mf(snapshot, :cil_part_number)
      line_data.units = mf(snapshot, :cil_units)
      line_data.tariff_lines = []

      line_data
    end

    def extract_tariff_data_from_invoice_line inv_line_snapshot

      tariff_lines = []
      primary_tariff_found = false
      json_child_entities(inv_line_snapshot, "CommercialInvoiceTariff") do |tariff|
        special_tariff = mf(tariff, "cit_special_tariff")

        add_tariff_standard_duties(tariff_lines, tariff)

        if !special_tariff && !primary_tariff_found
          primary_tariff_found = true
          add_invoice_line_taxes_fees(tariff_lines, inv_line_snapshot, tariff)
        end
      end

      tariff_lines
    end

    def add_invoice_line_taxes_fees tariff_lines, invoice_line, tariff
      mpf = mf(invoice_line, :cil_prorated_mpf)
      hmf = mf(invoice_line, :cil_hmf)
      fees = [mf(invoice_line, :cil_cotton_fee), mf(invoice_line, :cil_other_fees)].compact.sum
      add = mf(invoice_line, :cil_add_duty_amount)

      add_duty_data(tariff_lines, tariff, mf(invoice_line, :cil_prorated_mpf), "ALC_MPFUS")
      add_duty_data(tariff_lines, tariff, mf(invoice_line, :cil_hmf), "ALC_HMFUS")
      # This should include all other duty taxes
      add_duty_data(tariff_lines, tariff, [mf(invoice_line, :cil_cotton_fee), mf(invoice_line, :cil_other_fees)].compact.sum, "ALC_FEE")
      add_duty_data(tariff_lines, tariff, mf(invoice_line, :cil_add_duty_amount), "ALC_ADUS")
      add_duty_data(tariff_lines, tariff, mf(invoice_line, :cil_cvd_duty_amount), "ALC_CVDUS")
      nil
    end

    def add_tariff_standard_duties tariff_lines, tariff
      add_duty_data(tariff_lines, tariff, mf(tariff, "cit_duty_advalorem"), "ALC_AV_DTY")
      add_duty_data(tariff_lines, tariff, mf(tariff, "cit_duty_specific"), "ALC_SP_DTY")
      add_duty_data(tariff_lines, tariff, mf(tariff, "cit_duty_other"), "ALC_OT_DTY")

      nil
    end

    def add_duty_data tariff_lines, tariff, duty_amount, code
      if duty_amount && duty_amount > 0
        tariff_lines << KirklandsTariffData.new(mf(tariff, "cit_hts_code").to_s.gsub(".", ""), duty_amount, code, mf(tariff, "cit_spi_primary"))
        return true
      else
        return false
      end
    end

end; end; end; end