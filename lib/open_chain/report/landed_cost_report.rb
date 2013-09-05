require 'open_chain/report/report_helper'
require 'open_chain/report/landed_cost_data_generator'

module OpenChain; module Report
  class LandedCostReport
    include OpenChain::Report::ReportHelper

    def initialize run_by, parameters
      @run_by = run_by
      @alliance_customer_number = parameters['customer_number']
      # The date parameters should be formatted like YYYY-MM-DD
      @release_date_start = parameters['start_date']
      @release_date_end = parameters['end_date']
    end

    def self.run_report run_by, opts = {}
      LandedCostReport.new(run_by, opts).run
    end

    def self.permission? user
      (Rails.env=='development' || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
    end

    def run 
      wb = Spreadsheet::Workbook.new
      sheet = wb.create_worksheet :name=>"#{@alliance_customer_number} #{@release_date_start} - #{@release_date_end}"

      row_counter = 0
      row = sheet.row row_counter
      row.default_format = XlsMaker::HEADER_FORMAT
      [:ent_brok_ref, :ent_entry_num, :ent_release_date, :ent_transport_mode_code, :ent_customer_references, 
        :cit_hts_code, :cil_po_number, :cil_units, :cit_entered_value, "Entry Fee", "Other Fees", "Actual Freight", 
        :cil_hmf, :cil_prorated_mpf, :cil_cotton_fee, :cit_duty_amount, "Total Per Line", "Total Per Unit"].each_with_index do |v, i|

        write_val sheet, row, row_counter, i, ((v.is_a? String) ? v : ModelField.find_by_uid(v).label(false))
      end 

      query = Entry.where(:customer_number=>@alliance_customer_number)
        .where("entries.release_date > ? AND entries.release_date < ?", Time.zone.parse(@release_date_start), Time.zone.parse(@release_date_end))
      query = query.merge Entry.search_secure(@run_by, Entry.scoped)
      query = query.order("entries.release_date ASC, entries.broker_reference")
      
      # In order to conserve a bit of memory (and re-use the landed cost per entry api), 
      # we're just going to pull in the entry id initially and let the data generator re-lookup the full entry data
      # it needs to run all the calculations
      g = LandedCostDataGenerator.new
      query.pluck(:id).each do |id|
        lc = g.landed_cost_data_for_entry id

        # There's only one entry in this case
        entry = lc[:entries].first

        entry[:commercial_invoices].each do |invoice|
          invoice[:commercial_invoice_lines].each do |line|
            row_counter += 1
            row = sheet.row row_counter
            column = -1
            write_val sheet, row, row_counter, (column += 1), entry[:broker_reference]
            write_val sheet, row, row_counter, (column += 1), entry[:entry_number]
            write_val sheet, row, row_counter, (column += 1), entry[:release_date], :format=>ReportHelper::DATE_FORMAT_MMDDYY
            write_val sheet, row, row_counter, (column += 1), entry[:transport_mode_code]
            write_val sheet, row, row_counter, (column += 1), entry[:customer_reference].join(", ")
            write_val sheet, row, row_counter, (column += 1), line[:hts_code].collect{|h| h.hts_format}.join(", ")
            write_val sheet, row, row_counter, (column += 1), line[:po_number]
            write_val sheet, row, row_counter, (column += 1), line[:quantity]
            write_val sheet, row, row_counter, (column += 1), line[:entered_value], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:brokerage], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:other], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:international_freight], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:hmf], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:mpf], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:cotton_fee], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:duty], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:landed_cost], :format=>ReportHelper::CURRENCY_FORMAT
            write_val sheet, row, row_counter, (column += 1), line[:per_unit][:landed_cost].round(2, BigDecimal::ROUND_HALF_UP), :format=>ReportHelper::CURRENCY_FORMAT
          end
        end
      end

      workbook_to_tempfile wb, "Landed Cost #{@alliance_customer_number} "
    end

  end
end; end