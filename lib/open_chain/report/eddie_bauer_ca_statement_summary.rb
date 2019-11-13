require 'open_chain/report/report_helper'
require 'open_chain/report/eddie_bauer_statement_summary'

module OpenChain; module Report; class EddieBauerCaStatementSummary
  include OpenChain::Report::ReportHelper

  def self.permission? user
    (!Rails.env.production? || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
  end

  def self.run_report run_by, params = {}
    self.new.run run_by, HashWithIndifferentAccess.new(params)
  end

  def self.run_schedulable params = {}
    start_date, end_date = calculate_dates params['after_x_days_ago'], params['before_x_days_ago']
    report = self.new.run User.integration, start_date: start_date, end_date: end_date
    subject = "Eddie Bauer CA Statement Summary for #{start_date} to #{end_date}"
    OpenMailer.send_simple_html(params['email'], subject, "Attached is the #{subject}", [report]).deliver_now
    report.close
  end

  def run run_by, params = {}
    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date

    wb = XlsMaker.create_workbook "Billing Summary #{start_date} - #{end_date}", 
      ["Statement #","ACH #","Entry #","PO","Business","Invoice","Duty Rate","Duty","Taxes / Fees","Fees","ACH Date","Statement Date","Release Date","Unique ID", "Country of Origin", "LINK"]
    sheet = wb.worksheet 0
    cursor = 0
    column_widths = []

    entries = Entry.select("DISTINCT entries.*").
                joins(:broker_invoices).
                includes(:commercial_invoices => [:commercial_invoice_lines => [:commercial_invoice_tariffs]]).
                where(customer_number: "EBCC").
                where("broker_invoices.invoice_date >= ? ", start_date).
                where("broker_invoices.invoice_date < ?", end_date).
                order("entries.entry_filed_date ASC")

    entries = Entry.search_secure run_by, entries

    entries.each do |ent|
      # Only include entries where the brokerage fees don't total out to zero and there's no duty
      broker_enum = broker_invoice_lines(ent, run_by, start_date, end_date)
      fees = brokerage_fees broker_enum
      next unless fees.nonzero? || has_duty?(broker_enum)

      first_line = ent.commercial_invoice_lines.first
      ent.commercial_invoices.each do |ci|
        ci.commercial_invoice_lines.each do |cil|
          row = []
          row << ""
          row << ""
          row << ent.entry_number
          po, business = OpenChain::Report::EddieBauerStatementSummary.split_eddie_po_number cil.po_number
          row << po
          row << business
          row << ci.invoice_number
          duty_rate = cil.commercial_invoice_tariffs.collect {|cit| cit.duty_rate}.compact.max.try(:*, 100)
          row << duty_rate
          row << cil.total_duty
          row << cil.total_fees
          row << ((first_line.id == cil.id) ? fees : 0)
          row << ""
          row << ""
          row << ent.release_date
          row <<  "#{ent.entry_number}/#{duty_rate}/#{ci.invoice_number}"
          row << cil.country_origin_code
          row << Spreadsheet::Link.new(ent.view_url,'Web Link')

          XlsMaker.add_body_row sheet, (cursor+=1), row, column_widths
        end
      end
    end

    t = Tempfile.new(["EddieBauerCaStatementSummary-",".xls"])
    wb.write t
    t
  end

  private

    def broker_invoice_lines entry, run_by, start_date, end_date
      # Only include invoices that fall between the start and end dates.
      BrokerInvoice.where(entry_id: entry.id).
        where("broker_invoices.invoice_date >= ? ", start_date).
        where("broker_invoices.invoice_date < ?", end_date).
        includes(:broker_invoice_lines).each.
          map {|inv| inv.broker_invoice_lines.to_a}.flatten.to_enum
    end

    def brokerage_fees enum
      enum.collect { |bil| bil.duty_charge_type? ? BigDecimal.new("0") : bil.charge_amount }.sum       
    end

    def has_duty? enum
      enum.any? { |bil| bil.duty_charge_type? }
    end

    def self.calculate_dates after_x_days_ago, before_x_days_ago
      today = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.beginning_of_day
      start_date = (today - after_x_days_ago.days).to_date.strftime("%Y-%m-%d")
      end_date = (today - before_x_days_ago.days).to_date.strftime("%Y-%m-%d")
      [start_date, end_date]
    end

end; end; end
