require 'action_view/helpers/number_helper'
require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Siemens; class SiemensB2XmlGenerator
  attr_accessor :product_rollup, :total_values

  include OpenChain::XmlBuilder
  include ActionView::Helpers::NumberHelper
  include OpenChain::FtpFileSupport

  MAPPINGS = {
    importer_id: 1,
    previous_txn_number: 5,
    k84_account_date: 8,
    coo: 15,
    poe: 16,
    tariff_treatment: 17,
    currency_conversion_rate: 19,
    previous_txn_line: 20,
    line_number: 20,
    line_type: 21,
    product_number: 22,
    product_description: 23,
    hts: 24,
    invoice_quantity: 26,
    customs_duty_rate: 27,
    customs_duty: 28,
    gst_rate: 29,
    gst: 30,
    excise_tax_rate: 31,
    sima_code: 32,
    sima_assessment: 33,
    value_for_duty: 34,
    value_for_currency_conversion: 35,
    vfd_code: 36,
    purchase_order_number: 37,
    oic_code: 38,
    sub_header_row: 14,
    tariff_code: 25,
    ruling: 39,
    importer_name: 0,
    bn: 2,
    entry_number: 4,
    broker_file_number: 6,
    port_of_entry: 7,
    release_date: 9,
    summary_date: 12,
    currency_code: 18,
    caevl01: 50
  }.freeze

  B3Declaration ||= Struct.new(:importer_name, :entry_number, :broker_file_number, :port_of_entry,
                               :release_date, :currency_code, :currency_conversion_rate,
                               :declaration_lines, :entry_type, :summary_date, :bn, :total_value_for_duty, :total_excise_tax,
                               :total_customs_duty, :total_sima_assessment, :total_gst, :total_payable)

  B3DeclarationLine ||= Struct.new(:importer_id, :previous_txn_number, :k84_account_date, :previous_txn_line, :line_number,
                                   :product_number, :product_description, :hts, :invoice_quantity, :customs_duty_rate,
                                   :customs_duty, :gst_rate, :excise_tax_rate, :sima_code, :sima_assessment,
                                   :value_for_duty, :vfd_code, :purchase_order_number, :oic_code, :gst,
                                   :value_for_currency_conversion, :currency_conversion_rate, :coo, :poe, :tariff_treatment,
                                   :sub_header_row, :tariff_code, :ruling, :caevl01, :caevn01)

  def initialize(attachable)
    @attachable = attachable
    @product_rollup = {}
  end

  def self.can_view?(user)
    user.admin? && MasterSetup.get.custom_feature?("Siemens Feeds")
  end

  def can_view?(user)
    self.class.can_view?(user)
  end

  def process(user)
    @user = user
    begin
      raise "Processing Failed because you cannot view this file" unless self.class.can_view?(user)
      self.parse(OpenChain::XLClient.new_from_attachable(@attachable))
      user.messages.create!(subject: "Siemens B2 XML Processing Complete", body: "B2 process file complete")
    rescue StandardError => e
      if user.persisted?
        user.messages.create!(subject: 'Siemens B2 XML Processing Complete WITH ERRORS',
                              body: "B2 process file complete with the following error: #{e.message}")
      end
    end
  end

  def parse(xlclient)
    eligible_rows = xlclient.all_row_values.select { |row| row.present? && siemens?(row) }
    if eligible_rows.blank?
      user.messages.create!(subject: 'Siemens B2 XML Processing Complete WITH ERRORS',
                            body: "File imported does not have Siemens healthcare B2 data")
      return
    end

    entries = rollup_entries(eligible_rows)
    @product_rollup = rollup_products(eligible_rows)
    @total_values = calculate_product_values(@product_rollup)

    entries.each_value do |entry|
      doc = generate_xml(entry)
      send_xml(doc, entry)
    end
  end

  def generate_xml(row)
    entry = generate_structures(row)
    doc, elem_root = build_xml_document root_name
    add_namespace_content elem_root
    elem_dec = make_declaration_element elem_root, entry
    entry.declaration_lines.each do |line|
      make_declaration_line_element elem_dec, line
    end

    doc
  end

  def send_xml(doc, row)
    row = row.first
    current_time = ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S")
    entry_number = row[4]
    broker_number = entry_number[0..2]
    filename = "#{partner_id}_CA_B2_#{broker_number}_#{entry_number}_#{current_time}.xml"

    Tempfile.open(["siemens", ".xml"]) do |file|
      Attachment.add_original_filename_method(file, "#{filename}.xml")
      write_xml(doc, file)
      file.rewind
      ftp_file(file, connect_vfitrack_net("to_ecs/siemens_hc/b2", filename))
    end

    nil
  end

  def make_declaration_element(elem_root, entry)
    elem_dec = add_element(elem_root, "Declaration")
    add_element elem_dec, "EntryNum", entry.entry_number
    add_element elem_dec, "SummaryDate", entry.summary_date
    add_element elem_dec, "BrokerFileNum", entry.broker_file_number
    add_element elem_dec, "EntryType", entry.entry_type
    add_element elem_dec, "ReleaseDate", entry.release_date
    add_element elem_dec, "CurrencyCode", entry.currency_code
    add_element elem_dec, "PortOfEntry", entry.port_of_entry
    add_element elem_dec, "ImporterID", entry.bn
    add_element elem_dec, "ImporterName", entry.importer_name
    add_element elem_dec, "TotalValueForDuty", entry.total_value_for_duty
    add_element elem_dec, "TotalCustomsDuty", entry.total_customs_duty
    add_element elem_dec, "TotalSIMAAssessment", entry.total_sima_assessment
    add_element elem_dec, "TotalExciseTax", entry.total_excise_tax
    add_element elem_dec, "TotalGST", entry.total_gst
    add_element elem_dec, "TotalPayable", entry.total_payable
    elem_dec
  end

  def make_declaration_line_element(elem_dec, line)
    dec_line = add_element(elem_dec, "DeclarationLine")
    add_element(dec_line, "LineNum", line.line_number)
    add_element(dec_line, "CountryOfOrigin", line.coo)
    add_element(dec_line, "PlaceOfExport", line.poe)
    add_element(dec_line, "TariffTreatment", line.tariff_treatment)
    add_element(dec_line, "InvoiceQty", line.invoice_quantity)
    add_element(dec_line, "PurchaseOrderNum", line.purchase_order_number)
    add_element(dec_line, "ProductNum", line.product_number)
    add_element(dec_line, "ProductDesc", line.product_description)
    add_element(dec_line, "HsNum", line.hts.gsub('.', ''))
    add_element(dec_line, "PreviousTxnNum", line.previous_txn_number)
    add_element(dec_line, "PreviousTxnLine", line.previous_txn_line.split('/')[0])
    add_element(dec_line, "VFDCode", line.vfd_code)
    add_element(dec_line, "SIMACode", line.sima_code)
    add_element(dec_line, "CustomsDutyRate", line.customs_duty_rate)
    add_element(dec_line, "ExciseTaxRate", line.excise_tax_rate)
    add_element(dec_line, "GSTRate", line.gst_rate)
    add_element(dec_line, "CurrencyConversionRate", line.currency_conversion_rate)
    add_element(dec_line, "ValueForCurrencyConversion", line.value_for_currency_conversion)
    add_element(dec_line, "CustomsDuty", line.customs_duty)
    add_element(dec_line, "SIMAAssessment", line.sima_assessment)
    add_element(dec_line, "ExciseTax")
    add_element(dec_line, "GST", line.gst)
    add_element(dec_line, "OICCode", line.oic_code)
    add_element(dec_line, "K84AcctDate", line.k84_account_date)
    add_element(dec_line, "SubHeaderNum", line.sub_header_row)
    add_element(dec_line, "ValueForDuty", line.value_for_duty)
    add_element(dec_line, "TariffCode", line.tariff_code)
    special_authority = if line.ruling.present? && line.oic_code.present?
                          line.oic_code
                        elsif line.ruling.blank?
                          line.oic_code
                        elsif line.oic_code.blank?
                          line.ruling
                        end
    add_element(dec_line, "SpecialAuthority", special_authority)
    add_element(dec_line, "ClientNumber", line.importer_id)
    add_element(dec_line, "CAEVN01", line.caevn01)
    add_element(dec_line, "CAEVL01", line.caevl01)
  end

  def add_namespace_content(elem_root)
    elem_root.add_namespace 'xs', 'http://www.w3.org/2001/XMLSchema'
  end

  def rollup_products(rows)
    product_rollup = {}

    ['a', 'c'].each do |line_type|
      lines = rows.select { |row| row[MAPPINGS[:line_type]].downcase == line_type.downcase}
      lines.each do |line|
        product_rollup[line[MAPPINGS[:entry_number]]] ||= {}
        product_rollup[line[MAPPINGS[:entry_number]]][line_type.downcase] ||= []
        product_rollup[line[MAPPINGS[:entry_number]]][line_type.downcase] << line
      end
    end

    product_rollup
  end

  def partner_id
    MasterSetup.get.production? ? "100502" : "1005029"
  end

  def root_name
    "CA_EV"
  end

  def rollup_entries(eligible_rows)
    declaration_rollup = {}
    eligible_rows.each do |xlrow|
      declaration_rollup[xlrow[MAPPINGS[:entry_number]]] ||= []
      declaration_rollup[xlrow[MAPPINGS[:entry_number]]] << xlrow
    end

    declaration_rollup
  end

  def generate_structures(rows)
    entry = generate_declaration(rows.first)
    entry.declaration_lines ||= []

    rows.each do |row|
      next unless change?(row)
      entry.declaration_lines << generate_declaration_line(row)
    end

    entry
  end

  def calculate_product_values(product_rollup)
    line_type_a_values = {}
    line_type_c_values = {}
    total_values = {}

    sum_columns = [:value_for_duty, :customs_duty, :sima_assessment, :excise_tax_rate, :gst]

    product_rollup.each do |entry|
      entry_number = entry[0]
      parts = entry[1]

      sum_columns.each do |column|
        # In theory both a and c line types should be present. I don't trust theories, though.
        if parts['a'].present?
          line_type_a_values[column] = parts['a'].inject(0) { |sum, line| sum + line[MAPPINGS[column]].to_d }
        else
          line_type_a_values[column] = 0
        end

        if parts['c'].present?
          line_type_c_values[column] = parts['c'].inject(0) { |sum, line| sum + line[MAPPINGS[column]].to_d }
        else
          line_type_c_values[column] = 0
        end

        total_values[entry_number] ||= Hash.new(0)
        total_values[entry_number][column] += (line_type_c_values[column] - line_type_a_values[column])
        total_values[entry_number][:total_payable] += calculate_total_payable(column, total_values[entry_number][column])
      end
    end

    total_values
  end

  def calculate_total_payable(column, value)
    case column
    when :value_for_duty
      0
    when :gst
      if value > 0
        value
      else
        0
      end
    else
      value
    end
  end

  def generate_declaration_line(xlrow)
    entry_number = xlrow[MAPPINGS[:entry_number]]
    payable = total_values[entry_number][:total_payable]

    line = B3DeclarationLine.new
    line.importer_id = xlrow[MAPPINGS[:importer_id]]
    line.previous_txn_number = xlrow[MAPPINGS[:previous_txn_number]]
    line.k84_account_date = xlrow[MAPPINGS[:k84_account_date]]
    line.coo = xlrow[MAPPINGS[:coo]]
    line.poe = xlrow[MAPPINGS[:poe]]
    line.tariff_treatment = xlrow[MAPPINGS[:tariff_treatment]]
    line.currency_conversion_rate = xlrow[MAPPINGS[:currency_conversion_rate]]
    line.previous_txn_line = xlrow[MAPPINGS[:previous_txn_line]]
    line.line_number = xlrow[MAPPINGS[:line_number]]
    line.product_number = xlrow[MAPPINGS[:product_number]]
    line.product_description = xlrow[MAPPINGS[:product_description]]
    line.hts = xlrow[MAPPINGS[:hts]]
    line.invoice_quantity = xlrow[MAPPINGS[:invoice_quantity]]
    line.customs_duty_rate = xlrow[MAPPINGS[:customs_duty_rate]]
    line.customs_duty = xlrow[MAPPINGS[:customs_duty]]
    line.gst_rate = xlrow[MAPPINGS[:gst_rate]]
    line.gst = xlrow[MAPPINGS[:gst]]
    line.excise_tax_rate = xlrow[MAPPINGS[:excise_tax_rate]]
    line.sima_code = xlrow[MAPPINGS[:sima_code]]
    line.sima_assessment = xlrow[MAPPINGS[:sima_assessment]]
    line.value_for_duty = xlrow[MAPPINGS[:value_for_duty]]
    line.value_for_currency_conversion = xlrow[MAPPINGS[:value_for_currency_conversion]]
    line.vfd_code = xlrow[MAPPINGS[:vfd_code]]
    line.purchase_order_number = xlrow[MAPPINGS[:purchase_order_number]]
    line.oic_code = xlrow[MAPPINGS[:oic_code]]
    line.sub_header_row = xlrow[MAPPINGS[:sub_header_row]]
    line.tariff_code = xlrow[MAPPINGS[:tariff_code]]
    line.ruling = xlrow[MAPPINGS[:ruling]]
    line.caevn01 = caevn01_total(payable)
    line.caevl01 = xlrow[MAPPINGS[:caevl01]]

    line
  end

  def total_payable(value)
    value > 0 ? value : 0.00
  end

  def caevn01_total(value)
    value < 0 ? value.abs : 0.00
  end

  def generate_declaration(xlrow)
    entry_number = xlrow[MAPPINGS[:entry_number]]
    payable = total_values[entry_number][:total_payable]
    declaration = B3Declaration.new
    declaration.importer_name = xlrow[MAPPINGS[:importer_name]]
    declaration.bn = xlrow[MAPPINGS[:bn]]
    declaration.entry_number = entry_number
    declaration.broker_file_number = xlrow[MAPPINGS[:broker_file_number]]
    declaration.port_of_entry = xlrow[MAPPINGS[:port_of_entry]]
    declaration.release_date = xlrow[MAPPINGS[:release_date]]
    declaration.summary_date = xlrow[MAPPINGS[:summary_date]]
    declaration.currency_code = xlrow[MAPPINGS[:currency_code]]
    declaration.currency_conversion_rate = xlrow[MAPPINGS[:currency_conversion_rate]]
    declaration.entry_type = "B2"
    declaration.total_value_for_duty = total_values[entry_number][:value_for_duty]
    declaration.total_customs_duty = total_values[entry_number][:customs_duty]
    declaration.total_sima_assessment = total_values[entry_number][:sima_assessment]
    declaration.total_excise_tax = total_values[entry_number][:excise_tax_rate]
    declaration.total_gst = total_values[entry_number][:gst]
    declaration.total_payable = total_payable(payable)
    declaration
  end

  def siemens?(row)
    row[MAPPINGS[:bn]] == "807150586RM0001"
  end

  def change?(row)
    row[MAPPINGS[:line_type]].downcase == "c"
  end
end; end; end; end