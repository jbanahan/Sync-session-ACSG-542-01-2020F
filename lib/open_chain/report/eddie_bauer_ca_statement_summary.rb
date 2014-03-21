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

  def run run_by, params = {}
    start_date = params[:start_date]
    end_date = params[:end_date]

    wb = XlsMaker.create_workbook "Billing Summary #{start_date} - #{end_date}", 
      ["Statement #","ACH #","Entry #","PO","Business","Invoice","Duty Rate","Duty","Taxes / Fees","Fees","ACH Date","Statement Date","Release Date","Unique ID", "LINK"]
    sheet = wb.worksheet 0
    cursor = 0
    column_widths = []

    entries = Entry.select("DISTINCT entries.*").
                joins(:broker_invoices).
                includes(:commercial_invoices => [:commercial_invoice_lines => [:commercial_invoice_tariffs]]).
                where(customer_number: "EBCC").
                where("entries.entry_filed_date >= ? ", sanitize_date_string(start_date, run_by.time_zone)).
                where("entries.entry_filed_date < ?", sanitize_date_string(end_date, run_by.time_zone)).
                order("entries.entry_filed_date ASC")

    entries = Entry.search_secure run_by, entries

    entries.each do |ent|

      ent.commercial_invoices.each do |ci|
        last_line = ci.commercial_invoice_lines.last
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
          row << ((last_line.id == cil.id) ? ent.broker_invoice_lines.collect {|bil| bil.duty_charge_type? ? BigDecimal.new("0") : bil.charge_amount}.sum : "")
          row << ""
          row << ""
          row << ent.release_date
          row <<  "#{ent.entry_number}/#{duty_rate}/#{ci.invoice_number}"
          row << Spreadsheet::Link.new(ent.view_url,'Web Link')

          XlsMaker.add_body_row sheet, (cursor+=1), row, column_widths
        end
      end
    end

    t = Tempfile.new(["EddieBauerCaStatementSummary-",".xls"])
    wb.write t
    t
  end


end; end; end