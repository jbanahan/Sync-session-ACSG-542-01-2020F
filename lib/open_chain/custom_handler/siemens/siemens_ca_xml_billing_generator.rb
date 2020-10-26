require 'open_chain/custom_handler/thomson_reuters_entry_xml_generator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Siemens
  class SiemensCaXmlBillingGenerator < OpenChain::CustomHandler::ThomsonReutersEntryXmlGenerator
    include OpenChain::FtpFileSupport

    attr_reader :start_date, :description_memo

    SYNC_TRADING_PARTNER = "Siemens Billing".freeze
    TAX_IDS = ["807150586RM0001", "807150586RM0002"].freeze
    SYSTEM_DATE_ID = self.name

    def self.run_schedulable _opts = {}
      self.new.generate_and_send
    end

    def initialize
      @start_date = SystemDate.find_start_date(SYSTEM_DATE_ID)
      raise "SystemDate must be set." unless start_date
      @description_memo = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
    end

    def generate_and_send
      entries.find_each(batch_size: 50) { |ent| generate_and_send_entry(ent) }
    end

    def generate_and_send_entry entry
      doc = generate_xml entry
      send_xml doc, entry
    end

    def entries
      Entry.joins(importer: :system_identifiers)
           .joins(Entry.join_clause_for_need_sync(SYNC_TRADING_PARTNER))
           .where(system_identifiers: {system: "Fenix", code: TAX_IDS})
           .where(Entry.where_clause_for_need_sync(updated_at_column: :last_exported_from_source))
           .where("entry_type <> 'F'")
           .where("file_logged_date > ?", start_date)
           .order("entries.file_logged_date ASC")
    end

    def ftp_credentials
      connect_vfitrack_net("to_ecs/siemens_hc/b3#{MasterSetup.get.production? ? "" : "_test"}")
    end

    private

    def root_name
      "CA_EV"
    end

    def add_namespace_content elem_root
      elem_root.add_namespace 'xs', 'http://www.w3.org/2001/XMLSchema'
    end

    def make_declaration_element elem_root, entry
      elem_dec = super
      add_element elem_dec, "EntryClass", entry.entry_type
      add_element elem_dec, "EntryDate", format_date(entry.release_date)
      add_element elem_dec, "ImporterID", entry.importer_tax_id
      add_element elem_dec, "ImporterName", entry.customer_name
      add_element elem_dec, "OfficeNum", entry.entry_port_code
      add_element elem_dec, "GSTRegistrationNum", entry.importer_tax_id
      add_element elem_dec, "USPortOfExit", entry.us_exit_port_code
      add_element elem_dec, "CAPortOfUnlading", entry.entry_port_code
      add_element elem_dec, "Freight", entry.total_freight
      add_element elem_dec, "PaymentCode", "I"
      add_element elem_dec, "TotalValueForDuty", format_decimal(entry.entered_value)
      add_element elem_dec, "DirectShipmentDate", format_date(entry.direct_shipment_date)
      add_element elem_dec, "CarrierCode", entry.carrier_code
      add_element elem_dec, "CarrierName", entry.carrier_name
      add_element elem_dec, "TotalCustomsDuty", format_decimal(entry.commercial_invoice_tariffs
                                                                    .pluck(:duty_amount)
                                                                    .compact
                                                                    .sum)
      add_element elem_dec, "TotalSIMAAssessment", format_decimal(tariff_total(entry, :sima_amount))
      add_element elem_dec, "TotalExciseTax", format_decimal(tariff_total(entry, :excise_amount))
      add_element elem_dec, "TotalGST", format_decimal(tariff_total(entry, :gst_amount))

      total_payable = entry.total_duty + tariff_total(entry, :sima_amount) + tariff_total(entry, :excise_amount) + tariff_total(entry, :gst_amount)
      add_element elem_dec, "TotalPayable", format_decimal(total_payable)

      elem_dec
    end

    def tariff_total entry, meth
      entry.commercial_invoice_tariffs.map(&meth).compact.sum
    end

    def make_declaration_line_element elem_dec, entry, inv, inv_line, tar, tar_idx
      elem_line = super(elem_dec, entry, inv, inv_line, tar, tar_idx)
      add_element elem_line, "ClientNumber", entry.customer_number
      add_element elem_line, "CCINumber", inv_line.line_number
      add_element elem_line, "LineNum", inv_line.customs_line_number
      add_element elem_line, "SubHeaderNum", inv_line.subheader_number
      add_element elem_line, "CountryOfOrigin", inv_line.country_origin_code
      add_element elem_line, "PlaceOfExport", inv_line.country_export_code
      add_element elem_line, "SupplierID", inv.mfid
      add_element elem_line, "SpecialAuthority", tar.special_authority
      add_element elem_line, "ValueForCurrencyConversion", inv_line.value
      add_element elem_line, "Description", description(entry, inv, inv_line)
      add_element elem_line, "Freight", inv_line.freight_amount
      add_element elem_line, "UnitPrice", inv_line.unit_price
      # duplicates ThomsonReuters field
      add_element elem_line, "UnitPriceCurrencyCode", inv_line.currency.presence || inv.currency
      add_element elem_line, "CurrencyConversionRate", inv.exchange_rate
      add_element elem_line, "InvoiceQtyUom", inv_line.unit_of_measure
      add_element elem_line, "AirwayBillOfLading", (entry.air_mode? ? first_val(inv.house_bills_of_lading.presence || entry.house_bills_of_lading) : nil)
      add_element elem_line, "ProductDesc", tar.tariff_description
      add_element elem_line, "NetWeight", format_decimal(inv.net_weight)
      add_element elem_line, "TariffDuty", format_decimal(tar.duty_amount)
      add_element elem_line, "TariffRate", format_decimal(tar.duty_rate_description)
      add_element elem_line, "TariffCode", tar.tariff_provision
      add_element elem_line, "TariffTreatment", tar.spi_primary
      # duplicates TariffTreatment
      add_element elem_line, "PreferenceCode1", tar.spi_primary
      add_element elem_line, "VFDCode", tar.value_for_duty_code
      add_element elem_line, "SIMACode", tar.sima_code
      add_element elem_line, "CustomsDutyRate", format_decimal(tar.duty_rate_description)
      add_element elem_line, "ExciseTaxRate", tar.excise_rate_code
      add_element elem_line, "GSTRate", tar.gst_rate_code
      add_element elem_line, "TotalLineTax", format_decimal([tar.sima_amount, tar.gst_amount, tar.excise_amount].compact.sum)
      add_element elem_line, "ValueForDuty", format_decimal(tar.entered_value)
      add_element elem_line, "CustomsDuty", format_decimal(tar.duty_amount)
      add_element elem_line, "SIMAAssessment", format_decimal(tar.sima_amount)
      add_element elem_line, "ExciseTax", format_decimal(tar.excise_amount)
      add_element elem_line, "ValueForTax", format_decimal([tar.entered_value, tar.duty_amount, tar.sima_amount, tar.excise_amount].compact.sum)
      add_element elem_line, "GST", tar.gst_amount
      add_element elem_line, "CustomsInvoiceQty", tar.classification_qty_1
      add_element elem_line, "CustomsInvoiceQtyUOM", tar.classification_uom_1
      add_element elem_line, "K84AcctDate", format_date(entry.cadex_accept_date)
      add_element elem_line, "K84DueDate", format_date(entry.k84_due_date)
      add_element elem_line, "CargoControlNumber", entry.cargo_control_number
      make_pga_line_elements(elem_line, inv_line) if inv_line.canadian_pga_lines.present?

      elem_line
    end

    # Group lines by customs_line_number, then return the description of the tariff
    # belonging to the lowest line_number
    def description entry, inv, inv_line
      description_memo[entry.entry_number][inv.invoice_number][inv_line.customs_line_number] ||=
        begin
          inv.commercial_invoice_lines.select { |cil| cil.customs_line_number == inv_line.customs_line_number }
             .min_by(&:line_number)
             .commercial_invoice_tariffs
             .first
             .tariff_description
        end
    end

    def make_pga_line_elements elem_line, inv_line
      elem_pga_header = add_element elem_line, "CAPGAHeader"

      inv_line.canadian_pga_lines
              .group_by { |pga_ln| [pga_ln.agency_code, pga_ln.program_code] }
              .each do |(agency, program), pga_lines|
        elem_pga_agency = add_element elem_pga_header, "CAPGAAgency"
        add_element elem_pga_agency, "AgencyCode", agency
        add_element elem_pga_agency, "ProgramCode", program
        pga_lines.each { |line| make_pga_line_element elem_pga_agency, line }
      end

      nil
    end

    def make_pga_line_element elem_pga_agency, pga_line
      ingredients = pga_line.canadian_pga_line_ingredients

      # ensure there's at least one ingredients line so we always iterate
      ingredients.build if ingredients.empty?

      ingredients.each do |pga_line_ingredient|
        make_pga_line_ingredient_element(elem_pga_agency, pga_line, pga_line_ingredient)
      end

      nil
    end

    def make_pga_line_ingredient_element elem_pga_agency, pga_line, pga_line_ingredient
      elem_pga_line = add_element(elem_pga_agency, "CAPGADetails")
      add_element elem_pga_line, "BatchLotNumber", pga_line.batch_lot_number
      add_element elem_pga_line, "BrandName", pga_line.brand_name
      add_element elem_pga_line, "CommodityType", pga_line.commodity_type
      add_element elem_pga_line, "CountryofOrigin", pga_line.country_of_origin
      add_element elem_pga_line, "ExceptionProcess", pga_line.exception_processes
      add_element elem_pga_line, "ExpiryDate", format_date(pga_line.expiry_date)
      add_element elem_pga_line, "FDAProductCode", pga_line.fda_product_code
      add_element elem_pga_line, "File", pga_line.file_name
      add_element elem_pga_line, "GTINNumber", pga_line.gtin
      add_element elem_pga_line, "ImporterContactEmail", pga_line.importer_contact_email
      add_element elem_pga_line, "ImporterContactName", pga_line.importer_contact_name
      add_element elem_pga_line, "ImporterContactTelephoneNumber", pga_line.importer_contact_phone

      # ingredient fields
      add_element elem_pga_line, "IngredientQuality", format_decimal(pga_line_ingredient.quality)
      add_element elem_pga_line, "IngredientQuantity", format_decimal(pga_line_ingredient.quantity)
      add_element elem_pga_line, "Ingredients", pga_line_ingredient.name

      add_element elem_pga_line, "IntendedUse", pga_line.intended_use_code
      add_element elem_pga_line, "LPCONumber", pga_line.lpco_number
      add_element elem_pga_line, "LPCOType", pga_line.lpco_type
      add_element elem_pga_line, "ManufactureDate", format_date(pga_line.manufacture_date)
      add_element elem_pga_line, "ModelDesignation", pga_line.model_designation
      add_element elem_pga_line, "ModelName", pga_line.model_label
      add_element elem_pga_line, "ModelNumber", pga_line.model_number
      add_element elem_pga_line, "ProductName", pga_line.product_name
      add_element elem_pga_line, "Purpose", pga_line.purpose
      add_element elem_pga_line, "StateofOrigin", pga_line.state_of_origin
      add_element elem_pga_line, "UniqueDeviceIdentifierNumber", pga_line.unique_device_identifier

      nil
    end

    def send_xml doc, entry
      sync_record = SyncRecord.find_or_build_sync_record entry, SYNC_TRADING_PARTNER

      current_time = ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S")
      filename = "#{partner_id}_CA_B3_119_#{entry.entry_number}_#{current_time}"

      Tempfile.open(["siemens", ".xml"]) do |file|
        Attachment.add_original_filename_method(file, "#{filename}.xml")
        write_xml(doc, file)
        file.rewind
        ftp_sync_file file, sync_record
      end

      sync_record.sent_at = 1.second.ago
      sync_record.confirmed_at = 0.seconds.ago
      sync_record.save!

      nil
    end

    def partner_id
      MasterSetup.get.production? ? "100502" : "1005029"
    end

    def preload_entry entry
      incl = [{commercial_invoices: {commercial_invoice_lines: [:commercial_invoice_tariffs, {canadian_pga_lines: :canadian_pga_line_ingredients}]}}, :sync_records]
      ActiveRecord::Associations::Preloader.new.preload(entry, incl)
    end

  end
end; end; end
