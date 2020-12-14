require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'
require 'open_chain/supplemental_tariff_support'
require 'open_chain/custom_handler/target/target_support'
require "open_chain/custom_handler/target/target_document_packet_zip_generator"

# "CUSDEC" is Target's label for this outbound entry-based XML.  It's probably short for "Customs Declaration".
module OpenChain; module CustomHandler; module Target; class TargetCusdecXmlGenerator
  include OpenChain::FtpFileSupport
  include OpenChain::XmlBuilder
  include ActionView::Helpers::NumberHelper
  include OpenChain::CustomHandler::Target::TargetSupport
  include OpenChain::SupplementalTariffSupport

  SYNC_TRADING_PARTNER = 'TARGET_CUSDEC'.freeze

  CusdecTariffGrouping ||= Struct.new(:primary_tariff, :tariffs) do
    def initialize primary_tariff
      self.primary_tariff = primary_tariff
      self.tariffs ||= []
    end
  end

  class CusdecCounter
    attr_accessor :tariff_sequence_id, :pg01_line_number

    def initialize
      # This sequence ID is not meant to repeat in item tariff elements anywhere in the document.
      # It's a meaningless auto-generated field to us, but evidently has some importance to Target's system.
      @tariff_sequence_id = 1
      # This line number is unique within one itemRecord.  They can be duped within the document if there are
      # multiple items.
      @pg01_line_number = 1
    end

    def next_value field
      orig_value = send(field)
      send((field.to_s + "=").to_sym, orig_value + 1)
      orig_value
    end

    def reset field
      send((field.to_s + "=").to_sym, 1)
    end
  end

  def self.run_schedulable _opts = {}
    self.new.find_generate_and_send_entries
  end

  def find_generate_and_send_entries
    entries_query.find_each(batch_size: 50) do |entry|
      Lock.db_lock(entry) do
        generate_and_send entry
      end
    end
  end

  def target_importer_id
    @target_importer_id ||= Company.with_customs_management_number("TARGEN").first&.id
    raise "Target company record not found." unless @target_importer_id
    @target_importer_id
  end

  def generate_and_send entry
    preload_entry(entry)
    doc = generate_xml entry
    # Send the docs first.  This is largely because if something should happen in the send process
    # and cause something to raise.  We're using the sync records placed on the entry for the cusdec
    # as the marker that the whole process completed.  Thus, if a doc pack fails...then we can just
    # retry and send later and it's not a big deal if the docs are sent again.
    # However, if we sent the cusdec and marked the sync record as sent and the doc pack sends fail
    # then there's a possibility that the doc packs won't get sent at all.
    packet_generator.generate_and_send_doc_packs(entry)
    send_xml doc, entry
  end

  def generate_xml entry
    doc, elem_root = build_xml_document "entryRecord"
    populate_root_element elem_root, entry
    counter = CusdecCounter.new
    entry.commercial_invoices.each do |inv|
      uniq_7501_tariff_hash = {}
      elem_invoice = make_invoice_element elem_root, inv, entry
      make_bol_element elem_invoice, entry, inv
      inv.commercial_invoice_lines.each do |inv_line|
        elem_item = make_item_element elem_invoice, inv_line
        counter.reset :pg01_line_number
        primary_found = false
        inv_line.commercial_invoice_tariffs.each do |tariff|
          # The primary tariff is the first non-supplemental tariff encountered under the commercial invoice line.
          # Supplemental chapter 99 tariffs are typically sorted first, before the primary tariff, so we can't
          # assume position alone is enough to guarantee the primary.  It's probably safe to assume that XVV
          # tariffs will always have the "X" line sorted first, but this code should handle some random case
          # where that does not happen.  The primary tariff is the only one that should include duty elements
          # beneath it.
          primary_tariff = !primary_found && !supplemental_tariff?(tariff.hts_code) && tariff.spi_secondary != "V"
          if primary_tariff
            primary_found = true
          end

          # Every tariff results in an item tariff element.
          make_item_tariff_element elem_item, tariff, inv_line, counter, primary_tariff

          # Tariffs are lumped together by HTS code (and customs line number) for later inclusion in the tariff
          # header summary section of the XML.
          key = [inv_line.customs_line_number, tariff.hts_code]
          tariff_grouping = uniq_7501_tariff_hash[key]
          if tariff_grouping.nil?
            tariff_grouping = CusdecTariffGrouping.new(primary_tariff)
            uniq_7501_tariff_hash[key] = tariff_grouping
          end
          tariff_grouping.tariffs << tariff
        end
      end

      uniq_7501_tariff_hash.each_key do |key|
        tariff_grouping = uniq_7501_tariff_hash[key]
        make_tariff_header_element elem_invoice, tariff_grouping.tariffs, tariff_grouping.primary_tariff
      end
    end

    make_summary_record_element elem_root, entry

    doc
  end

  def cusdec_ftp_credentials
    connect_vfitrack_net("to_ecs/target_cusdec#{MasterSetup.get.production? ? "" : "_test"}")
  end

  private

    def entries_query
      # We're looking for entries who have a Summary Accepted Date and no Final Statement Date (entry is
      # considered over and done with if it has one of these dates set - however we need to ensure that we've
      # sent the cusdec at least once, so don't block sending cusdecs for files that haven't been sent but
      # have final statement dates).

      # Among these, we want entries where the Summary Accepted Date, compared to sync records, shows that a CUSDEC XML file has either
      # not been sent for the entry or the Summary Accepted Date has been updated since last send,
      # indicating we should send an updated CUSDEC.
      Entry.joins("LEFT OUTER JOIN sync_records AS sr ON entries.id = sr.syncable_id AND sr.syncable_type = 'Entry' AND ",
                  ActiveRecord::Base.sanitize_sql_array(['sr.trading_partner = ?', SYNC_TRADING_PARTNER]))
           .where(importer_id: target_importer_id)
           .where("entries.summary_accepted_date IS NOT NULL")
           .where("sr.sent_at IS NULL OR entries.summary_accepted_date > sr.sent_at")
           .where("(entries.final_statement_date IS NULL OR sr.sent_at IS NULL)")
    end

    def preload_entry entry
      ActiveRecord::Associations::Preloader.new.preload(entry, [{commercial_invoices: {commercial_invoice_lines: :commercial_invoice_tariffs}}, :sync_records])
    end

    def populate_root_element elem_root, entry
      add_element elem_root, "partnerId", "MRSKBROK"
      add_element elem_root, "entryDocumentId", Entry.format_entry_number(entry.entry_number)
      add_element elem_root, "entryTypeId", entry.entry_type
      add_element elem_root, "consolidatedEntry", format_boolean(entry.split_master_bills_of_lading.length > 1)
      add_element elem_root, "portOfLoading", entry.lading_port_code
      add_element elem_root, "portOfDischarge", entry.unlading_port_code
      add_element elem_root, "portOfEntry", entry.entry_port_code
      add_element elem_root, "locationOfGoodsId", [entry.location_of_goods, entry.location_of_goods_description].join("/")
      add_element elem_root, "inTransitDate", entry.first_it_date&.strftime("%Y%m%d")
      add_element elem_root, "filingDate", entry.last_7501_print&.strftime("%Y%m%d")
      add_element elem_root, "merchandiseExportDate", entry.export_date&.strftime("%Y%m%d")
      add_element elem_root, "anticipatedEntryDate", entry.release_date&.strftime("%Y%m%d")
      add_element elem_root, "merchandiseImportDate", entry.arrival_date&.strftime("%Y%m%d")
      add_element elem_root, "vesselArrivalDate", entry.import_date&.strftime("%Y%m%d")
      # Intentionally blank.
      add_element elem_root, "liquidationDate", nil
      add_element elem_root, "totalCartonsQuantity", entry.total_packages
      add_element elem_root, "bondTypeCode", entry.bond_type
      add_element elem_root, "bondId", entry.bond_surety_number
      # Intentionally blank.
      add_element elem_root, "teamId", nil
      add_element elem_root, "statusRequestCode", entry.paperless_release ? "PPLS" : "DOCS"
      add_element elem_root, "importerIrsId", Entry.format_importer_tax_id(entry.importer_tax_id)
      add_element elem_root, "inTransitBondMovementId", eat_newlines(entry.it_numbers)
      add_element elem_root, "transportModeCode", entry.transport_mode_code
      add_element elem_root, "carrierScacCode", entry.carrier_code
      add_element elem_root, "vesselName", entry.vessel
      broker_address = get_broker_address entry
      add_element elem_root, "brokerName", broker_address&.name
      add_element elem_root, "brokerAddressLine1", broker_address&.line_1
      add_element elem_root, "brokerAddressLine2", broker_address&.line_2
      add_element elem_root, "brokerCityName", broker_address&.city
      add_element elem_root, "brokerStateCode", broker_address&.state
      add_element elem_root, "brokerZipCode", broker_address&.postal_code
      add_element elem_root, "importerName", entry.ult_consignee_name
      add_element elem_root, "importerAddressLine1", entry.consignee_address_1
      add_element elem_root, "importerAddressLine2", entry.consignee_address_2
      add_element elem_root, "importerCityName", entry.consignee_city
      add_element elem_root, "importerStateCode", entry.consignee_state
      add_element elem_root, "importerZipCode", entry.consignee_postal_code
      add_element elem_root, "entryCottonAmount", format_money(entry.cotton_fee)
      add_element elem_root, "otherReconIndicator", get_other_recon_indicator(entry)
      add_element elem_root, "portOfEntrySummary", entry.entry_port_code
      add_element elem_root, "paymentTypeIndicator", entry.pay_type.to_i > 0 ? entry.pay_type.to_s : nil
    end

    def format_boolean val
      val ? "Y" : "N"
    end

    # Most fields used by this generator that COULD contain newlines probably will not
    # contain them for Target.  They're supposed to use only one BOL per invoice, for example.
    def eat_newlines str
      str&.gsub("\n ", ",")
    end

    # Involves caching.  If we're dealing with a series of entries, the chances that we will be dealing
    # with the same address for all/most of them are high.
    def get_broker_address entry
      filer_code = entry.entry_number[0, 3]
      division_number = entry.division_number.to_i.to_s
      @broker_address_cache ||= Hash.new do |hash, key|
        broker_address = nil
        broker_id = SystemIdentifier.where(system: "Filer Code", code: filer_code).pluck(:company_id).first
        if broker_id
          # It feels safe to assume the system identifier record won't have a bogus company_id in it.
          broker = Company.where(id: broker_id).first
          broker_address = broker.addresses.find { |addr| addr.system_code == division_number }
          if broker_address.nil?
            # Default to the Baltimore address if there's no match for a division.
            broker_address = broker.addresses.find { |addr| addr.system_code == "10" }
          end
        end
        hash[key] = broker_address
      end
      @broker_address_cache[[filer_code, division_number]]
    end

    def format_money val
      number_with_precision(val, precision: 2)
    end

    # This method functions similarly to a data cross reference, but is not the same.  Due to the way
    # we've shoehorned multiple flags into the same field on the entry side, this calls for a DIY solution.
    # This method will return a different result if multiple recon flags are used versus just one.
    def get_other_recon_indicator entry
      indicator = nil
      rc = entry.recon_flags&.upcase
      if rc
        if ["VALUE", "CLASS", "9802"].all? { |x| rc.include? x }
          indicator = "007"
        elsif ["CLASS", "9802"].all? { |x| rc.include? x }
          indicator = "006"
        elsif ["VALUE", "9802"].all? { |x| rc.include? x }
          indicator = "005"
        elsif ["VALUE", "CLASS"].all? { |x| rc.include? x }
          indicator = "004"
        elsif rc.include? "9802"
          indicator = "003"
        elsif rc.include? "CLASS"
          indicator = "002"
        elsif rc.include? "VALUE"
          indicator = "001"
        end
      end
      indicator
    end

    def make_invoice_element elem_root, invoice, entry
      elem_invoice = add_element(elem_root, "invoiceRecord")
      # Yes, this is an enty-level field as an invoice-level identifier.  To begin with, Target
      # will be doing single-invoice entries.  Whether this still makes sense once multi-invoice
      # is introduced remains to be seen.
      add_element elem_invoice, "brokerInvoice", entry.broker_reference
      add_element elem_invoice, "invoiceId", invoice.customer_reference&.gsub(/(\S{3})[.-]?(\S{2})[.-]?(\S{4})/, '\1-\2-\3')
      add_element elem_invoice, "invoiceCartonQuantity", format_decimal(invoice.total_quantity)
      add_element elem_invoice, "merchandiseProcessingFee", format_money(sum_line_value(invoice, :prorated_mpf))
      add_element elem_invoice, "harborMaintenanceFee", format_money(sum_line_value(invoice, :hmf))
      add_element elem_invoice, "invoiceCurrencyCode", invoice.currency
      add_element elem_invoice, "invoiceCurrencyRatePercent", format_decimal(invoice.exchange_rate)
      add_element elem_invoice, "totalInvoiceValueAmount", format_money(invoice.invoice_value)
      # Intentionally blank.
      add_element elem_invoice, "invoiceLocId", nil
      # Intentionally blank.
      add_element elem_invoice, "invoiceLocFolderId", nil
      invoice_value_foreign = format_money(invoice.invoice_value_foreign)
      add_element elem_invoice, "invoiceForeignValueAmount", invoice_value_foreign
      total_add_to_make_amount = format_money(sum_line_value(invoice, :add_to_make_amount))
      add_element elem_invoice, "invoiceMakeMarketValueAmount", total_add_to_make_amount
      non_dutiable_amount = format_money(invoice.non_dutiable_amount)
      add_element elem_invoice, "invoiceNonDutiableChargeAmount", non_dutiable_amount
      add_element elem_invoice, "invoiceNetValueAmount", format_money(BigDecimal(invoice_value_foreign || 0) +
                                                                        BigDecimal(total_add_to_make_amount || 0) - BigDecimal(invoice.non_dutiable_amount || 0))
      add_element elem_invoice, "itemExportCountryCode", invoice.commercial_invoice_lines.first&.country_export_code
      add_element elem_invoice, "invoiceDutyAmount", format_money(sum_tariff_value(invoice, :duty_amount))
      add_element elem_invoice, "invoiceAntiDumpingDutiesAmount", format_money(sum_line_value(invoice, :add_duty_amount))
      add_element elem_invoice, "invoiceCounterVailingDutiesAmount", format_money(sum_line_value(invoice, :cvd_duty_amount))
      add_element elem_invoice, "invoiceCottonFeeAmount", format_money(sum_line_value(invoice, :cotton_fee))
      # Intentionally blank.
      add_element elem_invoice, "invoiceTaxAmount", nil
      elem_invoice
    end

    # Looking for the original number from the database field with any pointless zeros removed.
    def format_decimal val, percentage_multiplier: BigDecimal(1)
      val *= percentage_multiplier unless val.nil?
      number_with_precision(val, precision: 10, strip_insignificant_zeros: true)
    end

    def sum_line_value invoice, field_name
      sum_value invoice.commercial_invoice_lines, field_name
    end

    def sum_value arr, field_name
      arr.inject(BigDecimal("0")) {|total, line| line.send(field_name) ? total + line.send(field_name) : total }
    end

    def sum_tariff_value invoice, field_name
      invoice.commercial_invoice_lines.inject(BigDecimal("0")) { |total, line| total + sum_value(line.commercial_invoice_tariffs, field_name)}
    end

    # Target invoices should contain only a single bill of lading and a single PO.  Nice n' easy.
    def make_bol_element elem_invoice, entry, invoice
      elem_bol = add_element(elem_invoice, "bolRecord")
      # Although the field is only supposed to contain one BOL, safe coding dictates that we eat any newlines.
      add_element elem_bol, "masterBillOfLadingNumber", eat_newlines(invoice.master_bills_of_lading.presence || invoice.invoice_number)
      add_element elem_bol, "totalCartonsQuantity", format_decimal(invoice.total_quantity)
      add_element elem_bol, "unitOfMeasure", invoice.total_quantity_uom
      # Although the field is only supposed to contain one BOL, safe coding dictates that we eat any newlines.
      add_element elem_bol, "houseBillNumber", eat_newlines(invoice.house_bills_of_lading)
      add_element elem_bol, "issuerCodeOfHouseBillNumber", (invoice.house_bills_of_lading.present? ? entry.carrier_code : nil)
      first_line = invoice.commercial_invoice_lines.first
      add_element elem_bol, "sourcePurchaseOrderId", [first_line&.department&.rjust(4, '0'), first_line&.po_number].compact.join("-")
      # It's safe to assume this will be the same for all ines.
      add_element elem_bol, "relatedParty", format_boolean(first_line&.related_parties)
      elem_bol
    end

    def make_item_element elem_invoice, inv_line
      elem_item = add_element(elem_invoice, "itemRecord")
      add_element elem_item, "departmentClassItem", (inv_line.part_number ? split_part_number(inv_line.part_number)[0] : nil)
      add_element elem_item, "itemCostAmount", format_money(inv_line.unit_price)
      add_element elem_item, "itemCostUom", "PE"
      # Intentionally blank.
      add_element elem_item, "itemRoyaltiesAmount", nil
      # Intentionally blank.
      add_element elem_item, "itemBuyingCommissionAmount", nil
      add_element elem_item, "itemDutyAmount", format_money(inv_line.duty_plus_fees_amount)
      # Intentionally blank.
      add_element elem_item, "itemForeighTradeZoneCode", nil
      # Intentionally blank.
      add_element elem_item, "itemForeignTradeZoneDate", nil
      add_element elem_item, "itemQuantity", format_decimal(inv_line.quantity)
      add_element elem_item, "itemQuantityUom", inv_line.unit_of_measure
      add_element elem_item, "itemBindRuleId", (inv_line.ruling_type.to_s == 'R' ? inv_line.ruling_number : nil)
      # Mapping document and samples indicate that the botched camel-casing of this element name is, if
      # not intentional, at least expected.  As we don't really have an item-level carton quantity, we
      # are sending a zero value for now.
      add_element elem_item, "totalItemcartonQuantity", "0"
      add_element elem_item, "dpciItemDescription", get_product_name(inv_line.part_number)
      add_element elem_item, "itemFreightAmount", format_money(inv_line.freight_amount)
      # Our gross weight field is currently an integer for some reason.  We'll handle it as a decimal
      # here just in case that's ever corrected.
      add_element elem_item, "itemWeight", format_decimal(inv_line.gross_weight)
      add_element elem_item, "itemUomCode", "K"
      elem_item
    end

    def get_product_name part_number
      @product_name_cache ||= Hash.new do |hash, key|
        hash[key] = Product.where(unique_identifier: key, importer_id: target_importer_id).first&.name
      end
      @product_name_cache[part_number]
    end

    def make_item_tariff_element elem_item, tariff, inv_line, counter, include_duty_elements
      elem_tariff = add_element(elem_item, "itemTariffRecord")
      add_element elem_tariff, "tariffSeqId", counter.next_value(:tariff_sequence_id)
      add_element elem_tariff, "tariffId", tariff.hts_code&.hts_format
      # Intentionally blank.
      add_element elem_tariff, "primaryTariffId", nil
      add_element elem_tariff, "itemOriginatingCountryCode", inv_line.country_origin_code
      add_element elem_tariff, "spi1", tariff.spi_primary
      add_element elem_tariff, "spi2", tariff.spi_secondary
      # Intentionally blank.
      add_element elem_tariff, "spi3", nil
      add_element elem_tariff, "visaQuantity", format_decimal(inv_line.visa_quantity)
      add_element elem_tariff, "visaUom", inv_line.visa_uom
      add_element elem_tariff, "agricultureLicenseNumber", inv_line.agriculture_license_number
      add_element elem_tariff, "itemVisaId", inv_line.visa_number
      if tariff.classification_qty_1.to_i > 0
        add_element elem_tariff, "hsQuantityUomCode1", tariff.classification_uom_1
        add_element elem_tariff, "hsQuantity1", format_decimal(tariff.classification_qty_1)
      end
      if tariff.classification_qty_2.to_i > 0
        add_element elem_tariff, "hsQuantityUomCode2", tariff.classification_uom_2
        add_element elem_tariff, "hsQuantity2", format_decimal(tariff.classification_qty_2)
      end
      if tariff.classification_qty_3.to_i > 0
        add_element elem_tariff, "hsQuantityUomCode3", tariff.classification_uom_3
        add_element elem_tariff, "hsQuantity3", format_decimal(tariff.classification_qty_3)
      end
      add_element elem_tariff, "itemAddCaseId", inv_line.add_case_number
      add_element elem_tariff, "itemAddBondId", format_boolean(inv_line.add_bond)
      add_element elem_tariff, "itemAddTax", format_money(inv_line.add_duty_amount)
      add_element elem_tariff, "itemAddRate", format_decimal(inv_line.add_case_percent)
      add_element elem_tariff, "itemCvdCaseId", inv_line.cvd_case_number
      add_element elem_tariff, "itemCvdBondId", format_boolean(inv_line.cvd_bond)
      add_element elem_tariff, "itemCvdTax", format_money(inv_line.cvd_duty_amount)
      add_element elem_tariff, "itemCvdRate", format_decimal(inv_line.cvd_case_percent)
      add_element elem_tariff, "htsManufactureId", inv_line.mid
      add_element elem_tariff, "harmonizedScheduleLineId", inv_line.customs_line_number.to_s.rjust(3, "0")

      if include_duty_elements
        make_item_tariff_duty_element elem_tariff, "ADD", inv_line.add_case_percent, inv_line.add_duty_amount
        make_item_tariff_duty_element elem_tariff, "CVD", inv_line.cvd_case_percent, inv_line.cvd_duty_amount
        make_item_tariff_duty_element elem_tariff, "HMF", inv_line.hmf_rate, inv_line.hmf, percentage_multiplier: BigDecimal(100)
        make_item_tariff_duty_element elem_tariff, "MPF", inv_line.mpf_rate, inv_line.prorated_mpf, percentage_multiplier: BigDecimal(100)
        make_item_tariff_duty_element elem_tariff, "COF", inv_line.cotton_fee_rate, inv_line.cotton_fee
      end
      # These duty types need to be included regardless of the inclue_duty_elements flag value.
      make_item_tariff_duty_element elem_tariff, "SPECFC", tariff.specific_rate, tariff.duty_specific
      make_item_tariff_duty_element elem_tariff, "ADVAL", tariff.advalorem_rate, tariff.duty_advalorem, percentage_multiplier: BigDecimal(100)
      make_item_tariff_duty_element elem_tariff, "OTHER", tariff.additional_rate, tariff.duty_additional

      make_pga_element elem_tariff, tariff, counter

      elem_tariff
    end

    def make_item_tariff_duty_element elem_tariff, code, percentage, amount, percentage_multiplier: BigDecimal(1)
      elem_duty = nil
      if amount.to_f > 0
        elem_duty = add_element(elem_tariff, "itemTariffDutyRecord")
        add_element elem_duty, "dutyTypeCode", code
        add_element elem_duty, "hsRatePercentage", format_decimal(percentage, percentage_multiplier: percentage_multiplier)
        add_element elem_duty, "rateAmount", format_money(amount)
      end
      elem_duty
    end

    def make_pga_element elem_tariff, tariff, counter
      elem_pga = nil
      if tariff.pga_summaries.length > 0
        elem_pga = add_element(elem_tariff, "pgaData")
        add_element elem_pga, "commercialDescription", tariff.pga_summaries[0].commercial_description
        tariff.pga_summaries.each do |p|
          make_pg01_element elem_pga, p, counter
        end
      end
      elem_pga
    end

    def make_pg01_element elem_pga, pga_summary, counter
      elem_pg01 = add_element(elem_pga, "pg01Data")
      add_element elem_pg01, "lineNumber", counter.next_value(:pg01_line_number)
      add_element elem_pg01, "governmentAgencyCode", pga_summary.agency_code
      add_element elem_pg01, "governmentAgencyProgramCode", pga_summary.program_code
      add_element elem_pg01, "governmentAgencyProcessingCode", pga_summary.agency_processing_code
      add_element elem_pg01, "disclaimerFlag", pga_summary.disclaimer_type_code
    end

    def make_tariff_header_element elem_invoice, tariffs, include_duty_elements
      elem_tariff = add_element(elem_invoice, "tariffHeaderRecord")
      tariff_prime = tariffs[0]
      inv_line = tariff_prime.commercial_invoice_line
      add_element elem_tariff, "harmonizedScheduleLineId", inv_line.customs_line_number.to_s.rjust(3, "0")
      add_element elem_tariff, "tariffId", tariff_prime.hts_code&.hts_format
      # Intentionally blank.
      add_element elem_tariff, "primaryTariffId", nil
      add_element elem_tariff, "htsQuotaCategoryId", tariff_prime.quota_category
      add_element elem_tariff, "valueAmount", format_money(sum_value(tariffs, :entered_value))
      # Intentionally blank.
      add_element elem_tariff, "classCode", nil
      tariff_qty_1 = sum_value(tariffs, :classification_qty_1)
      if tariff_qty_1 > 0
        add_element elem_tariff, "hsQuantityUom1", tariff_prime.classification_uom_1
        add_element elem_tariff, "hsQuantity1", format_decimal(tariff_qty_1)
      end
      tariff_qty_2 = sum_value(tariffs, :classification_qty_2)
      if tariff_qty_2 > 0
        add_element elem_tariff, "hsQuantityUom2", tariff_prime.classification_uom_2
        add_element elem_tariff, "hsQuantity2", format_decimal(tariff_qty_2)
      end
      tariff_qty_3 = sum_value(tariffs, :classification_qty_3)
      if tariff_qty_3 > 0
        add_element elem_tariff, "hsQuantityUom3", tariff_prime.classification_uom_3
        add_element elem_tariff, "hsQuantity3", format_decimal(tariff_qty_3)
      end
      add_element elem_tariff, "tariffDescription", tariff_prime.tariff_description

      if include_duty_elements
        lines = tariff_invoice_lines(tariffs)
        make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "ADD", inv_line.add_case_percent, sum_value(lines, :add_duty_amount)
        make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "CVD", inv_line.cvd_case_percent, sum_value(lines, :cvd_duty_amount)
        make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "HMF", inv_line.hmf_rate, sum_value(lines, :hmf), percentage_multiplier: BigDecimal(100)
        make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "MPF", inv_line.mpf_rate, sum_value(lines, :prorated_mpf), percentage_multiplier: BigDecimal(100)
        make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "COF", inv_line.cotton_fee_rate, sum_value(lines, :cotton_fee)
      end
      # These duty types need to be included regardless of the inclue_duty_elements flag value.
      legit_tariffs = tariffs.reject { |t| t.spi_secondary == "V" }
      make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "SPECFC", tariff_prime.specific_rate, sum_value(legit_tariffs, :duty_specific)
      make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "ADVAL", tariff_prime.advalorem_rate, sum_value(legit_tariffs, :duty_advalorem),
                               percentage_multiplier: BigDecimal(100)
      make_tariff_duty_element elem_tariff, tariff_prime.hts_code, "OTHER", tariff_prime.additional_rate, sum_value(legit_tariffs, :duty_additional)
      elem_tariff
    end

    def tariff_invoice_lines tariffs
      line_hash = {}
      tariffs.each do |tar|
        if !line_hash.include? tar.commercial_invoice_line.id
          line_hash[tar.commercial_invoice_line.id] = tar.commercial_invoice_line
        end
      end
      line_hash.values
    end

    def make_tariff_duty_element elem_tariff, hts_code, code, percentage, amount, percentage_multiplier: BigDecimal(1)
      elem_duty = nil
      if amount.to_f > 0
        elem_duty = add_element(elem_tariff, "tariffDutyRecord")
        add_element elem_duty, "tariffId", hts_code&.hts_format
        add_element elem_duty, "dutyTypeCode", code
        add_element elem_duty, "hsRatePercentage", format_decimal(percentage, percentage_multiplier: percentage_multiplier)
        add_element elem_duty, "rateAmount", format_money(amount)
      end
      elem_duty
    end

    def make_summary_record_element elem_root, entry
      elem_summary = add_element(elem_root, "summaryRecord")
      add_element elem_summary, "totalDutyAmount", format_money(entry.total_duty_taxes_fees_amount)
      add_element elem_summary, "entryOtherAmount", format_money(entry.total_fees)
      add_element elem_summary, "entryTaxAmount", format_money(entry.total_taxes)
      add_element elem_summary, "entryDutyAmount", format_money(entry.total_duty)
      add_element elem_summary, "entryMerchandiseProcessingFeeAmount", format_money(entry.mpf)
      add_element elem_summary, "entryHarborMaintenanceFeeAmount", format_money(entry.hmf)
      add_element elem_summary, "totalEntryValueAmount", format_money(entry.entered_value)
      elem_summary
    end

    def send_xml doc, entry
      sync_record = SyncRecord.find_or_build_sync_record entry, SYNC_TRADING_PARTNER

      # Because we're acquiring a lock on the entry on the outer edge if the send process, a transaction isn't required here
      Tempfile.open(["ENTRY_FILE_", ".xml"]) do |file|
        Attachment.add_original_filename_method(file, "ENTRY_FILE_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S%L")}.xml")
        write_xml(doc, file)
        file.rewind
        ftp_sync_file file, sync_record, cusdec_ftp_credentials
      end

      sync_record.sent_at = 1.second.ago
      sync_record.confirmed_at = 0.seconds.ago
      sync_record.save!

      nil
    end

    def packet_generator
      OpenChain::CustomHandler::Target::TargetDocumentPacketZipGenerator.new
    end

end; end; end; end