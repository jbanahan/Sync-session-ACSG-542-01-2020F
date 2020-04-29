require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; class CustomerInvoiceHandler
  include OpenChain::Report::ReportHelper

  def initialize custom_file
    @custom_file = custom_file
  end

  def process user, parameters
    p = Parser.new.parse @custom_file, parameters
    self.class.email_errors(user, @custom_file.attached_file_name, p.errors) if p.errors.present?
  end

  def can_view? user
    self.class.can_view? user
  end

  def self.can_view? user
    user.company.master? && MasterSetup.get.custom_feature?("Customer Invoice Uploader")
  end

  def self.valid_file? file_name
    [".XLSX", ".XLS", ".CSV"].include? File.extname(file_name).to_s.upcase
  end

  def self.email_errors user, file_name, errors
    subject = "Custom invoice upload incomplete"
    inv_nums = errors.map {|n| CGI.escapeHTML n }.join("<br>").html_safe
    body = "<p>The following invoices in <strong>#{CGI.escapeHTML file_name}</strong> already exist and could not be updated:<br>#{inv_nums}</p>".html_safe
    OpenMailer.send_simple_html(user.email, subject, body).deliver_now
  end

  class Wrapper < RowWrapper
    FIELD_MAP = {invoice_number: 0, vendor_name: 1, factory_name: 2, invoice_total_foreign: 3, currency: 4, ln_po_number: 5,
                 ln_middleman_charge: 6, ln_air_sea_discount: 7, ln_early_pay_discount: 8, ln_trade_discount: 9, ln_part_number: 10,
                 ln_part_description: 11, invoice_date: 12, customer_reference_number: 13, goods_description: 14, invoice_total_domestic: 15,
                 total_discounts: 16, total_charges: 17, exchange_rate: 18, net_invoice_total: 19, net_weight: 20, net_weight_uom: 21,
                 country_origin_iso: 22, payment_terms: 23, sale_terms: 24, ship_mode: 25, total_gross_weight: 26, total_gross_weight_uom: 27,
                 total_volume: 28, total_volume_uom: 29, ln_department: 30, ln_country_export_iso: 31, ln_first_sale: 32, ln_fish_and_wildlife: 33,
                 ln_gross_weight: 34, ln_gross_weight_uom: 35, ln_hts: 36, ln_line_number: 37, ln_mid: 38, ln_net_weight: 39, ln_net_weight_uom: 40,
                 ln_country_origin_iso: 41, ln_pieces: 42, ln_quantity: 43, ln_quantity_uom: 44, ln_unit_price: 45, ln_value_domestic: 46,
                 ln_value_foreign: 47, ln_volume: 48, ln_volume_uom: 49}

    def initialize row
      super row, FIELD_MAP
    end
  end

  class Parser
    include OpenChain::CustomHandler::CustomFileCsvExcelParser

    attr_reader :errors

    def initialize
      @co_cache = {}
    end

    def parse custom_file, parameters
      @errors = []; lines = []
      prev_inv_number = nil
      cust_num = parameters['cust_num']
      file_name = custom_file.attached_file_name
      importer = Company.where(system_code: cust_num).first

      foreach(custom_file) do |row|
        r = Wrapper.new row
        next if r[:invoice_number].to_s =~ /Invoice Number/
        curr_inv_number = text_value r[:invoice_number]
        if prev_inv_number && prev_inv_number != curr_inv_number
          process_invoice(lines, cust_num, importer, file_name)
          lines = []
        end
        lines << r
        prev_inv_number = curr_inv_number
      end
      process_invoice(lines, cust_num, importer, file_name)
      self
    end

    def process_invoice lines, cust_num, importer, file_name
      inv = nil; proceed = nil
      inv_number = text_value lines.first[:invoice_number]
      raise "Missing invoice number!" unless inv_number
      Lock.acquire("Invoice-#{cust_num}-#{inv_number}") do
        inv = Invoice.where(importer_id: importer.id, invoice_number: inv_number).first_or_initialize
        proceed = inv.manually_generated? || inv.new_record?
        inv.save! if proceed && inv.new_record?
      end
      # only allow updates to new invoices, those created with uploader
      if proceed
        Lock.with_lock_retry(inv) do
          assign_invoice_header inv, lines.first, importer.system_code
          inv.invoice_lines.destroy_all
          lines.each { |line| process_invoice_line(inv, line) }
          inv.save!
          inv.create_snapshot User.integration, nil, "Custom Invoice Uploader: #{file_name}"
        end
      else
        @errors << inv_number
      end
    end

    def assign_invoice_header inv, line, imp_uid
      assign_header_fields inv, line
      inv.vendor = vendor(line, imp_uid)
      inv.factory = factory(line, imp_uid)

      nil
    end

    def assign_header_fields inv, line
      inv.manually_generated = true
      inv.exchange_rate = decimal_value line[:exchange_rate]
      inv.gross_weight = decimal_value line[:total_gross_weight]
      inv.gross_weight_uom = text_value line[:total_gross_weight_uom]
      inv.invoice_date = date_value line[:invoice_date]
      inv.currency = text_value line[:currency]
      inv.invoice_total_foreign = decimal_value line[:invoice_total_foreign]
      inv.invoice_total_domestic = decimal_value line[:invoice_total_domestic]
      inv.customer_reference_number = text_value line[:customer_reference_number]
      inv.description_of_goods = text_value line[:goods_description]
      inv.total_discounts = decimal_value line[:total_discounts]
      inv.total_charges = decimal_value line[:total_charges]
      inv.net_invoice_total = decimal_value line[:net_invoice_total]
      inv.net_weight = decimal_value line[:net_weight]
      inv.net_weight_uom = text_value line[:net_weight_uom]
      inv.country_origin = country_cache text_value(line[:country_origin_iso])
      inv.terms_of_payment = text_value line[:payment_terms]
      inv.terms_of_sale = text_value line[:sale_terms]
      inv.ship_mode = text_value line[:ship_mode]
      inv.volume = decimal_value line[:total_volume]

      nil
    end

    def vendor line, imp_uid
      vend_name = text_value line[:vendor_name]
      Company.where(vendor: true, name: vend_name, system_code: "#{imp_uid}-VENDOR-#{vend_name}").first_or_create!
    end

    def factory line, imp_uid
      fact_name = text_value line[:factory_name]
      Company.where(factory: true, name: fact_name, system_code: "#{imp_uid}-FACTORY-#{fact_name}").first_or_create!
    end

    def process_invoice_line inv, line
      ln = inv.invoice_lines.build

      ln.air_sea_discount = decimal_value line[:ln_air_sea_discount]
      ln.department =  text_value line[:ln_department]
      ln.early_pay_discount = decimal_value line[:ln_early_pay_discount]
      ln.trade_discount = decimal_value line[:ln_trade_discount]
      ln.fish_wildlife = boolean_value line[:ln_fish_and_wildlife]
      ln.line_number = integer_value line[:ln_line_number]
      ln.middleman_charge = decimal_value line[:ln_middleman_charge]
      ln.net_weight = decimal_value line[:ln_net_weight]
      ln.net_weight_uom = text_value line[:ln_net_weight_uom]
      ln.part_description = text_value line[:ln_part_description]
      ln.part_number = text_value line[:ln_part_number]
      ln.po_number = text_value line[:ln_po_number]
      ln.pieces = decimal_value line[:ln_pieces]
      ln.quantity = decimal_value line[:ln_quantity]
      ln.quantity_uom = text_value line[:ln_quantity_uom]
      ln.value_foreign = decimal_value line[:ln_value_foreign]
      ln.value_domestic = decimal_value line[:ln_value_domestic]
      ln.unit_price = decimal_value line[:ln_unit_price]
      ln.country_export = country_cache text_value(line[:ln_country_export_iso])
      ln.first_sale = boolean_value line[:ln_first_sale]
      ln.gross_weight = decimal_value line[:ln_gross_weight]
      ln.gross_weight_uom = text_value line[:ln_gross_weight_uom]
      ln.hts_number = text_value line[:ln_hts]
      ln.mid = text_value line[:ln_mid]
      ln.country_origin = country_cache text_value(line[:ln_country_origin_iso])
      ln.volume = decimal_value line[:ln_volume]
      ln.volume_uom = text_value line[:ln_volume_uom]

      line
    end

    def country_cache iso_code
      @co_cache[iso_code] ||= Country.where(iso_code: iso_code).first
    end
  end

end; end; end
