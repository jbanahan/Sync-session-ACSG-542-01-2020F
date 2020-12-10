require 'open_chain/custom_handler/thomson_reuters_entry_xml_generator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Ferguson; class FergusonEntryVerificationXmlGenerator < OpenChain::CustomHandler::ThomsonReutersEntryXmlGenerator
  include OpenChain::FtpFileSupport

  SYNC_TRADING_PARTNER = 'FERGUSON_DECLARATION'.freeze

  def self.run_schedulable _opts = {}
    parser = self.new
    entries = Entry.joins("LEFT OUTER JOIN sync_records AS sr ON entries.id = sr.syncable_id AND sr.syncable_type = 'Entry' AND ",
                          ActiveRecord::Base.sanitize_sql_array(['sr.trading_partner = ?', SYNC_TRADING_PARTNER]))
                   .where(customer_number: ferguson_customer_numbers)
                   .where.not(release_date: nil)
                   .where("sr.sent_at IS NULL OR entries.last_exported_from_source > sr.sent_at")
                   .where("entries.entry_type IS NULL OR entries.entry_type != '06' OR entries.first_entry_sent_date IS NOT NULL")

    entries.find_each(batch_size: 50) do |entry|
      Lock.db_lock(entry) do
        parser.generate_and_send entry
      end
    end
  end

  def self.ferguson_customer_numbers
    ["FERENT", "HPPRO"]
  end

  def generate_and_send entry
    doc = generate_xml entry
    send_xml doc, entry
  end

  def root_name
    "US_EV"
  end

  def add_namespace_content elem_root
    elem_root.add_namespace 'xsi', 'http://www.w3.org/2001/XMLSchema-instance'
    elem_root.add_attribute 'xsi:noNamespaceSchemaLocation', 'Standard_US_EV_PGA_Import.xsd'
  end

  def make_declaration_element elem_root, entry
    elem_dec = super
    add_element elem_dec, "SummaryDate", format_date(entry.first_entry_sent_date)
    # Intentionally sending nothing for this element.
    add_element elem_dec, "BrokerLocation", nil
    add_element elem_dec, "CustomerID", entry.customer_number
    add_element elem_dec, "CustomerName", entry.customer_name
    add_element elem_dec, "TxnDate", format_date(ActiveSupport::TimeZone["America/New_York"].now)
    add_element elem_dec, "EntryDate", format_date(entry.release_date)
    add_element elem_dec, "ExportCountryCode", first_val(entry.export_country_codes)
    add_element elem_dec, "ReconciliationFlag", entry.recon_flags
    add_element elem_dec, "USPortOfUnlading", entry.unlading_port_code
    add_element elem_dec, "IORNum", entry.importer_tax_id
    add_element elem_dec, "BondType", entry.bond_type
    add_element elem_dec, "IORName", entry.customer_name
    add_element elem_dec, "ExportDate", format_date(entry.export_date)
    add_element elem_dec, "ImportDate", format_date(entry.import_date)
    add_element elem_dec, "ActLiquidationDate", format_date(entry.liquidation_date)
    add_element elem_dec, "AssistFlag", format_boolean(assist?(entry))
    add_element elem_dec, "BondSurety", entry.bond_surety_number
    add_element elem_dec, "DestinationState", entry.destination_state
    add_element elem_dec, "EstimatedDateOfArrival", format_date(entry.arrival_date)
    add_element elem_dec, "TotalHmfAmt", format_decimal(entry.hmf)
    add_element elem_dec, "TotalMpfAmt", format_decimal(entry.mpf)
    add_element elem_dec, "VesselName", entry.vessel
    add_element elem_dec, "VoyageFlightNum", entry.voyage
    add_element elem_dec, "LocationOfGoods", entry.location_of_goods
    add_element elem_dec, "PaymentTypeIndicator", entry.pay_type.to_s
    add_element elem_dec, "ITDate", format_date(entry.first_it_date)
    add_element elem_dec, "TotalCharges", format_decimal(entry.total_duty_taxes_fees_amount)
    add_element elem_dec, "ShipDate", format_date(entry.commercial_invoices.map(&:invoice_date).compact.first)
    add_element elem_dec, "PostSummaryCorrection", format_boolean(entry.post_summary_correction?)
    add_element elem_dec, "FTZNumber", ftz_number(entry)
    elem_dec
  end

  def make_declaration_line_element elem_dec, entry, inv, inv_line, tar, tariff_sequence_number
    elem_line = super
    add_element elem_line, "LineNum", inv_line.customs_line_number.to_s
    add_element elem_line, "CountryOfOrigin", inv_line.country_origin_code
    add_element elem_line, "ManufacturerId", inv_line.mid
    add_element elem_line, "SPICode1", tar.spi_primary
    add_element elem_line, "SPICode2", tar.spi_secondary
    add_element elem_line, "HsDesc", tar.tariff_description
    add_element elem_line, "AdValoremDuty", format_decimal(tar.duty_advalorem)
    add_element elem_line, "MpfAmt", format_decimal(inv_line.prorated_mpf)
    add_element elem_line, "HmfAmt", format_decimal(inv_line.hmf)
    add_element elem_line, "CottonFee", format_decimal(inv_line.cotton_fee)
    add_element elem_line, "AdValoremRate", format_decimal(tar.advalorem_rate)
    add_element elem_line, "ADDFlag", format_boolean(inv_line.add_case_number.present?)
    add_element elem_line, "ADCaseNum", inv_line.add_case_number
    add_element elem_line, "ADDuty", format_decimal(inv_line.add_duty_amount)
    add_element elem_line, "CVDFlag", format_boolean(inv_line.cvd_case_number.present?)
    add_element elem_line, "CVCaseNum", inv_line.cvd_case_number
    add_element elem_line, "CVDuty", format_decimal(inv_line.cvd_duty_amount)
    add_element elem_line, "InvoiceQtyUOM", inv_line.unit_of_measure
    add_element elem_line, "RelatedPartyFlag", format_boolean(inv_line.related_parties)
    add_element elem_line, "SpecificDuty", format_decimal(tar.duty_specific)
    add_element elem_line, "ReferenceNum", (tariff_sequence_number + 1).to_s
    add_element elem_line, "VisaNum", inv_line.visa_number
    add_element elem_line, "FreightCharge", format_decimal(inv_line.freight_amount)
    add_element elem_line, "FreightChargeCurrencyCode", inv_line.currency
    add_element elem_line, "InvoiceExchangeRate", format_decimal(inv.exchange_rate)
    add_element elem_line, "InvoiceLineNum", inv_line.line_number.to_s
    add_element elem_line, "LineGrossWeight", tar.gross_weight.to_s
    add_element elem_line, "UnitPrice", format_decimal(inv_line.unit_price)
    add_element elem_line, "AddlDuty", format_decimal(tar.duty_additional)
    add_element elem_line, "AddlDutyRate", format_decimal(tar.additional_rate)
    elem_line
  end

  def ftp_credentials
    connect_vfitrack_net("to_ecs/ferguson_entry_verification#{MasterSetup.get.production? ? "" : "_test"}")
  end

  def self.filename_system_prefix
    MasterSetup.get.production? ? "118011" : "1180119"
  end

  private

    def assist? entry
      entry.commercial_invoices.any? do |ci|
        ci.commercial_invoice_lines.any? do |cil|
          (cil.add_to_make_amount || BigDecimal(0)) > 0 || (cil.other_amount || BigDecimal(0)) > 0
        end
      end
    end

    def ftz_number entry
      entry.entry_type == '06' ? entry.vessel : nil
    end

    def send_xml doc, entry
      sync_record = SyncRecord.find_or_build_sync_record entry, SYNC_TRADING_PARTNER

      doc_type = entry.post_summary_correction? ? "PSC" : "7501"
      current_time = ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S")
      filename_minus_suffix = "#{self.class.filename_system_prefix}_#{doc_type}_316_#{entry.entry_number}_#{current_time}"

      Tempfile.open([filename_minus_suffix, ".xml"]) do |file|
        Attachment.add_original_filename_method(file, "#{filename_minus_suffix}.xml")
        write_xml(doc, file)
        file.rewind
        ftp_sync_file file, sync_record
      end

      sync_record.sent_at = 1.second.ago
      sync_record.confirmed_at = 0.seconds.ago
      sync_record.save!

      nil
    end

end; end; end; end
