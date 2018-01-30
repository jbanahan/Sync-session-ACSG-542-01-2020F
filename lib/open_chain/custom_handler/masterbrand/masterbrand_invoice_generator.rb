require 'open_chain/invoice_generator_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Masterbrand; class MasterbrandInvoiceGenerator
  extend OpenChain::InvoiceGeneratorSupport
  include OpenChain::Report::ReportHelper

  ENTRY_UNIT_PRICE = 2.50
  ENTRY_LIMIT = 250
  MONTHLY_UNIT_PRICE = 1000.00

  def self.run_schedulable settings
    inv = under_limit = over_limit = nil
    ActiveRecord::Base.transaction do
      inv = create_invoice
      under_limit = get_new_billables(ENTRY_LIMIT)
      bill_monthly_charge(under_limit ,inv)
      over_limit = get_new_billables
      bill_new_entries(over_limit, inv)
    end
    entry_ids = (under_limit + over_limit).map(&:billable_eventable_id)
    detail_tmp = ReportGenerator.new.create_report_for_invoice entry_ids, inv
    email_invoice inv, settings['email'], title, title, detail_tmp if settings["email"]
  end

  def self.title
    date = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].today - 1.month).strftime("%m-%y")
    "MasterBrand autobill invoice #{date}"
  end

  def self.create_invoice
    co = Company.where(master: true).first
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def self.bill_monthly_charge billables, invoice
    line = invoice.vfi_invoice_lines.create! vfi_invoice: invoice, quantity: 1, unit: "ea", unit_price: MONTHLY_UNIT_PRICE, charge_description: "Monthly charge for up to #{ENTRY_LIMIT} entries"
    write_invoiced_events billables, line
  end

  def self.get_new_billables limit=nil
    be = BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"')
                 .joins('INNER JOIN entries e ON billable_events.billable_eventable_type = "Entry" and billable_events.billable_eventable_id = e.id')
                 .where('ie.id IS NULL')
                 .where('billable_events.event_type = "entry_new"')
                 .where('e.file_logged_date >= "2016-05-01" OR e.file_logged_date IS NULL')
    be = be.limit(limit) if limit
    be
  end

  def self.bill_new_entries billables, invoice
    return if billables.empty?
    line = invoice.vfi_invoice_lines.create! quantity: billables.length, unit: "ea", unit_price: ENTRY_UNIT_PRICE, charge_description: "Unified Entry Audit; Over #{ENTRY_LIMIT} Entries"
    write_invoiced_events billables, line
  end

  def self.write_invoiced_events billables, invoice_line
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'MasterbrandInvoiceGenerator', charge_type: 'unified_entry_line')
      end
    end
  end

  class ReportGenerator
    include OpenChain::Report::ReportHelper
    
    def create_report_for_invoice entry_ids, invoice
      file_name = "entries_for_#{invoice.invoice_number}.xls"
      att = invoice.attachments.new(attached_file_name: file_name, attachment_type: "VFI Invoice Support")
      wb = create_workbook(entry_ids, invoice.invoice_number)
      detail_tmp = workbook_to_tempfile(wb, "", file_name: file_name)
      att.update_attributes! attached: detail_tmp
      detail_tmp
    end
    
    def create_workbook entry_ids, invoice_number
      wb = XlsMaker.create_workbook invoice_number
      table_from_query wb.worksheet(0), query(entry_ids)
      wb
    end
    
    private

    def query entry_ids
      <<-SQL
        SELECT entry_number AS "Entry Number"
        FROM entries
        WHERE id IN (#{entry_ids.empty? ? "\"\"" : entry_ids.join(",")})
        ORDER BY entry_number
      SQL
    end
  end

end; end; end; end
