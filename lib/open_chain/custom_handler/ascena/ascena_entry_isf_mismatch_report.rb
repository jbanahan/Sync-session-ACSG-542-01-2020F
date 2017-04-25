require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Ascena; class AscenaEntryIsfMismatchReport
  include OpenChain::Report::ReportHelper

  def self.run_schedulable config = {}
    start_date, end_date = dates
    tf = self.new.run_report ascena, start_date, end_date
    OpenMailer.send_simple_html(config["email"], "Ascena Entry/ISF Mismatch #{start_date.to_date} - #{end_date.to_date}", "The Entry/ISF Mismatch report for Entry Summary Sent Dates between #{start_date.to_date} - #{end_date.to_date} is attached.", [tf]).deliver!
  end

  def self.dates 
    now = Time.zone.now.in_time_zone("America/New_York").midnight
    start_date = now - 7.days
    end_date = now + 7.days
    [start_date, end_date]
  end

  def self.ascena
    Company.importers.where(alliance_customer_number: "ASCE").first
  end

  def run_report importer, start_date, end_date
    wb, sheet = XlsMaker.create_workbook_and_sheet "Entry / ISF Match"

    row_number = 0
    column_widths = [20, 25, 20, 20, 30, 30, 20, 20, 20, 20, 10, 10, 10, 10, 10, 10, 10]
    XlsMaker.set_column_widths sheet, column_widths
    XlsMaker.add_header_row sheet, 0, report_headers, column_widths

    entries = Entry.where(importer_id: importer.id, transport_mode_code: ["10", "11"]).where("first_entry_sent_date >= ? AND first_entry_sent_date < ?", start_date.in_time_zone("UTC"), end_date.in_time_zone("UTC")).where("first_entry_sent_date > '2017-04-21'").pluck :id
    entries.each do |id|
      entry = Entry.where(id: id).includes(:commercial_invoices => [:commercial_invoice_lines=>[:commercial_invoice_tariffs]]).first

      isf = SecurityFiling.where(importer_id: entry.importer_id).where("entry_reference_numbers LIKE ?", "%#{entry.broker_reference}%").includes(:security_filing_lines).first

      # Kewill's ISF system is terribly bad at not VFI Track updates containing the entry numbers.  So, we're going to also see if we can find 
      # an ISF by the master bill.
      isf = SecurityFiling.where(importer_id: entry.importer_id).where("master_bill_of_lading = ?", entry.master_bills_of_lading).includes(:security_filing_lines).first

      if isf.nil?
        add_exception_row(sheet, (row_number+=1), column_widths, entry, nil, nil, nil, nil, nil, nil, nil, nil, nil)
      else
        entry.commercial_invoices.each do |invoice|
          invoice.commercial_invoice_lines.each do |line|
            line.commercial_invoice_tariffs.each do |tariff|
              match = matches(line, tariff, isf)

              if !match.matches?
                add_exception_row sheet, (row_number += 1), column_widths, entry, line, tariff, isf, match.isf_line, true, match.hts_match, match.coo_match, match.po_match, match.style_match
              end
            end
          end
        end
      end
    end

    workbook_to_tempfile wb, "EntryISfMatch", file_name: "Entry ISF Match.xls"
  end

  def report_headers 
    ["Transaction Number", "Master Bill", "Container Number", "Entry Number", "Country of Origin Code (ISF)", "Country of Origin Code (Entry)", "PO Number (ISF)", "PO Number (Entry)", "Part Number (ISF)", "Part Number (Entry)", "HTS Code (ISF)", "HTS Code (Entry)", "ISF Match", "HTS Match", "COO Match", "PO Match", "Style Match"]
  end


  def add_exception_row sheet, row_number, column_widths, entry, invoice_line, tariff_line, isf, isf_line, isf_match, hts_match, coo_match, po_match, style_match
    row = []
    row << field(isf.try(:transaction_number), "")
    row << field(isf.try(:master_bill_of_lading), entry.master_bills_of_lading)
    row << field(isf.try(:container_numbers), entry.container_numbers)
    row << entry.entry_number
    row << isf_line.try(:country_of_origin_code)
    row << invoice_line.try(:country_origin_code)
    row << isf_line.try(:po_number)
    row << invoice_line.try(:po_number)
    row << isf_line.try(:part_number)
    row << invoice_line.try(:part_number)
    row << isf_line.try(:hts_code).to_s.hts_format
    row << tariff_line.try(:hts_code).to_s.hts_format
    row << (isf_match ? "Y" : "N")
    row << (hts_match ? "Y" : "N")
    row << (coo_match ? "Y" : "N")
    row << (po_match ? "Y" : "N")
    row << (style_match ? "Y" : "N")

    XlsMaker.add_body_row sheet, row_number, row, column_widths
  end

  def field isf_value, entry_value
    isf_value.presence || entry_value
  end

  def matches line, tariff, isf
    # basically, we're looking for a single line that as close as possible matches the invoice line / tariff...so what
    # we'll do is evaluate all the lines to see how well each of the criteria matches...and if we find a line that 
    # matches them all, we'll say it matches...if we don't fine one, then we'll return the best match
    matches = []

    isf.security_filing_lines.each do |isf_line|
      match = IsfMatch.new isf_line

      match.hts_match = isf_line.hts_code.strip.to_s[0..5] == tariff.hts_code.strip.to_s[0..5]
      match.coo_match = isf_line.country_of_origin_code.to_s.strip.upcase == line.country_origin_code.to_s.strip.upcase
      match.po_match = isf_line.po_number.to_s.strip.upcase == line.po_number.to_s.strip.upcase
      match.style_match = isf_line.part_number.to_s.strip.upcase == line.part_number.to_s.strip.upcase

      matches << match

      # no use continuing to look for rows if all the criteria match
      break if match.matches?
    end

    # Return the "most matched" result
    matches.sort!

    matches.first
  end

  def full_match? matches_hash
    matches_hash.values.uniq.first == true
  end

  class IsfMatch 

    attr_reader :isf_line
    attr_accessor :hts_match, :coo_match, :po_match, :style_match

    def initialize isf_line
      @isf_line = isf_line
    end

    def <=> m
      # Evaluate whatever match has the most matches as the 
      v = m.match_count <=> match_count

      if v == 0
        v = m.isf_line.line_number <=> isf_line.line_number
      end

      v
    end

    def match_count
      count = 0
      count += 1 if hts_match
      count += 1 if coo_match
      count += 1 if po_match
      count += 1 if style_match

      count
    end

    def matches?
      match_count == 4
    end
  end


end; end; end; end