require 'open_chain/report/report_helper'
require 'open_chain/report/landed_cost_data_generator'
require 'open_chain/mutable_number'

module OpenChain; module Report
  class LandedCostReport
    include OpenChain::Report::ReportHelper

    def initialize run_by, parameters
      @run_by = run_by
      @customer_number = parameters['customer_number']
      @entry_number = parameters['entry_number']
      # The date parameters should be formatted like YYYY-MM-DD
      @release_date_start = parameters['start_date']
      @release_date_end = parameters['end_date']
    end

    def self.run_report run_by, opts = {}
      LandedCostReport.new(run_by, opts).run
    end

    # takes output of LandedCostGenerator
    def self.run_report_from_lc_data run_by, lc_hsh, opts={}, &proc
      LandedCostReport.new(run_by, opts).run_from_lc_data lc_hsh, proc
    end

    def self.permission? user
      MasterSetup.get.custom_feature?("WWW VFI Track Reports") && user.company.master?
    end

    def create_report arg
      headers = [:ent_brok_ref, :ent_entry_num, :ent_release_date, :ent_transport_mode_code, :ent_customer_references,
        :cit_hts_code, :cil_country_origin_code, :cil_po_number, :cil_part_number, :cil_units, :cit_entered_value, "Entry Fee", "Other Fees", "Actual Freight",
        :cil_hmf, :cil_prorated_mpf, :cil_cotton_fee, :cit_duty_amount, "Total Per Line", "Total Per Unit"].map {|v| ((v.is_a? String) ? v : ModelField.find_by_uid(v).label(false))}

      tab = @entry_number || "#{@customer_number} #{@release_date_start} - #{@release_date_end}"
      wb = XlsMaker.create_workbook tab, headers
      sheet = wb.worksheets[0]

      column_widths = []
      row_counter = MutableNumber.new 0
      # In order to conserve a bit of memory (and re-use the landed cost per entry api),
      # we're just going to pull in the entry id initially and let the data generator re-lookup the full entry data
      # it needs to run all the calculations
      g = LandedCostDataGenerator.new
      Array.wrap(arg[:entry_ids]).each { |id| add_entry_from_db id, sheet, g, row_counter, column_widths  }
      Array.wrap(arg[:entry_hashes]).each { |hsh| add_entry_from_hsh sheet, hsh, row_counter, column_widths }
      wb
    end

    def add_entry_from_db id, sheet, generator, row_counter=MutableNumber.new(0), column_widths=[]
      lc_hsh = generator.landed_cost_data_for_entry id
      add_entry sheet, lc_hsh, row_counter, column_widths
    end

    def add_entry_from_hsh sheet, lc_hsh, row_counter=MutableNumber.new(0), column_widths=[]
      add_entry sheet, lc_hsh, row_counter, column_widths
    end

    def add_entry sheet, lc_hsh, row_counter, column_widths
      # There's only one entry in this case
      entry = lc_hsh[:entries].first

      entry[:commercial_invoices].each do |invoice|
        invoice[:commercial_invoice_lines].each do |line|
          row_counter.value += 1
          column = -1

          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), entry[:broker_reference], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), entry[:entry_number], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), entry[:release_date], column_widths, :format=>ReportHelper::DATE_FORMAT_MMDDYY
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), entry[:transport_mode_code], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), entry[:customer_reference].join(", "), column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:hts_code].collect {|h| h.hts_format}.join(", "), column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:country_origin_code], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:po_number], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:part_number], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:quantity], column_widths
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:entered_value], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:brokerage], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:other], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:international_freight], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:hmf], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:mpf], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:cotton_fee], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:duty], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:landed_cost], column_widths, :format=>ReportHelper::CURRENCY_FORMAT
          XlsMaker.insert_cell_value sheet, row_counter.value, (column += 1), line[:per_unit][:landed_cost].round(2, BigDecimal::ROUND_HALF_UP), column_widths, :format=>ReportHelper::CURRENCY_FORMAT
        end
      end
    end

    def run
      query = Entry.where(:customer_number=>@customer_number)
        .where("entries.release_date > ? AND entries.release_date < ?", Time.zone.parse(@release_date_start), Time.zone.parse(@release_date_end))
      query = query.merge Entry.search_secure(@run_by, Entry.all)
      query = query.order("entries.release_date ASC, entries.broker_reference")
      wb = create_report(entry_ids: query.pluck(:id))
      workbook_to_tempfile wb, "Landed Cost #{@customer_number} "
    end

    def run_from_lc_data hashes, proc=nil
      wb = create_report(entry_hashes: hashes)
      if proc
        workbook_to_tempfile wb, "Landed Cost #{@entry_number}", &proc
      else
        workbook_to_tempfile wb, "Landed Cost #{@entry_number}"
      end
    end

  end
end; end
