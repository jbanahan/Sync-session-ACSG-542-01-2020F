require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Hm; class HmInvoiceGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  UNIT_PRICE = 2.00
  
  def self.run_schedulable
    generator = self.new
    ActiveRecord::Base.transaction do
      billables = generator.get_new_billables
      inv = generator.create_invoice
      generator.bill_new_classifications(billables[:to_be_invoiced], inv)
      ReportGenerator.new(generator.cdefs).create_report_for_invoice(billables[:to_be_invoiced], inv)
      generator.write_non_invoiced_events(billables[:to_be_skipped])
    end
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_po_numbers, :prod_part_number]
  end

  def get_new_billables
    events = BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "HmInvoiceGenerator"')
                          .joins('LEFT OUTER JOIN non_invoiced_events nie ON billable_events.id = nie.billable_event_id AND nie.invoice_generator_name = "HmInvoiceGenerator"')
                          .joins('INNER JOIN classifications cla ON cla.id = billable_eventable_id INNER JOIN countries cou ON cou.id = cla.country_id AND cou.iso_code = "CA" INNER JOIN products p ON cla.product_id = p.id INNER JOIN companies com ON com.id = p.importer_id AND com.alliance_customer_number = "HENNE"')
                          .where('ie.id IS NULL AND nie.id IS NULL')
                          .where('billable_eventable_type = "Classification"')
    to_be_invoiced, to_be_skipped = partition_by_order_type events
    {to_be_invoiced: to_be_invoiced, to_be_skipped: to_be_skipped}
  end

  def create_invoice
    co = Company.where(alliance_customer_number: "HENNE").first
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def bill_new_classifications billables, invoice
    qty_to_bill = billables.count
    if qty_to_bill > 0
      line = invoice.vfi_invoice_lines.create!(charge_description: "Canadian classification", quantity: qty_to_bill, unit: "ea", unit_price: UNIT_PRICE)
      write_invoiced_events(billables, line)
    end
  end

  def write_invoiced_events billables, invoice_line
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'HmInvoiceGenerator', charge_type: 'classification_ca')
      end
    end
  end

  def write_non_invoiced_events billables
    BillableEvent.transaction do
      billables.each do |e|
        NonInvoicedEvent.create!(billable_event_id: e[:id], invoice_generator_name: "HmInvoiceGenerator")
      end
    end
  end

  class ReportGenerator
    include OpenChain::Report::ReportHelper
    attr_accessor :cdefs
    
    def initialize cdefs=nil
      @cdefs = cdefs
    end
    
    def create_report_for_invoice billables, invoice
      file_name = "products_for_#{invoice.invoice_number}.xls"
      att = invoice.attachments.new(attached_file_name: file_name, attachment_type: "VFI Invoice Support")
      wb = create_workbook(billables, invoice.invoice_number)
      workbook_to_tempfile(wb, "", file_name: file_name) { |t| att.attached = t }
      att.save!
    end
    
    def create_workbook billables, invoice_number
      wb = XlsMaker.create_workbook invoice_number
      table_from_query wb.worksheet(0), query(billables.map(&:id))
      wb
    end
    
    private

    def query billable_ids
      <<-SQL
        SELECT part_no.string_value AS "Part Number"
        FROM products prod
        INNER JOIN custom_values part_no ON prod.id = part_no.customizable_id AND part_no.customizable_type = "Product" AND part_no.custom_definition_id = #{cdefs[:prod_part_number].id}
        INNER JOIN classifications cl ON prod.id = cl.product_id
        INNER JOIN billable_events be ON be.billable_eventable_id = cl.id AND be.billable_eventable_type = "Classification"
        WHERE be.id IN (#{billable_ids.empty? ? "\"\"" : billable_ids.join(",")})
        ORDER BY part_no.string_value
      SQL
    end
  end

  private

  def partition_by_order_type billables
    billables.partition do |be|
      prod = be.billable_eventable.product
      po_nums = prod.custom_value(cdefs[:prod_po_numbers]).try(:split, /\r?\n */) || []
      found = po_nums.find { |po| po[0] == '1' }
      !found.nil?
    end
  end

end; end; end; end