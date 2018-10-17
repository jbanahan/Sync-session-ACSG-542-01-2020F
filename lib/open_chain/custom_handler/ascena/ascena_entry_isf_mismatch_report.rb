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
    column_widths = [20, 20, 20, 20, 10, 20, 20, 20, 20, 30, 30, 10, 10, 10, 10, 10, 10, 10, 100]
    XlsMaker.set_column_widths sheet, column_widths
    XlsMaker.add_header_row sheet, 0, report_headers, column_widths

    entries = Entry.where(importer_id: importer.id, transport_mode_code: ["10", "11"]).where("first_entry_sent_date >= ? AND first_entry_sent_date < ?", start_date.in_time_zone("UTC"), end_date.in_time_zone("UTC")).where("first_entry_sent_date > '2017-04-21'").pluck :id
    entries.each do |id|
      entry = Entry.where(id: id).includes(:commercial_invoices => [:commercial_invoice_lines=>[:commercial_invoice_tariffs]]).first

      isfs = []

      isfs.push *SecurityFiling.where(importer_id: entry.importer_id).where("entry_reference_numbers LIKE ?", "%#{entry.broker_reference}%").includes(:security_filing_lines).all

      # Kewill's ISF system is terribly bad at not VFI Track updates containing the entry numbers.  So, we're going to also see if we can find 
      # an ISF by the master bill.
      master_bills = entry.split_master_bills_of_lading
      isfs.push *SecurityFiling.where(importer_id: entry.importer_id).where("master_bill_of_lading in (?)", master_bills).includes(:security_filing_lines).all if master_bills.length > 0

      # We also don't always get master bills for ISF's (apparently for some LCL files), so lets also find by the house bills on the entry
      house_bills = entry.split_house_bills_of_lading
      isfs.push(*SecurityFiling.where(importer_id: entry.importer_id).where("house_bills_of_lading IN (?)", house_bills).includes(:security_filing_lines).all) if house_bills.length > 0

      # Reject any isfs that don't have isf lines
      isfs = isfs.find_all {|i| i.security_filing_lines.length > 0 }

      if isfs.length == 0
        add_exception_row(sheet, (row_number+=1), column_widths, entry, nil, nil, nil, nil)
      else
        entry.commercial_invoices.each do |invoice|
          invoice.commercial_invoice_lines.each do |line|
            tariffs = line.commercial_invoice_tariffs.to_a
            match = matches(line, tariffs, isfs)

            if !match.matches?
              add_exception_row sheet, (row_number += 1), column_widths, entry, line, tariffs, match.isf, match
            end
          end
        end
      end
    end

    workbook_to_tempfile wb, "EntryISfMatch", file_name: "Entry ISF Match.xls"
  end

  def report_headers 
    ["ISF Transaction Number", "Master Bill", "House Bills", "Broker Reference", "Brand", "PO Number (Entry)", "PO Number (ISF)", "Part Number (Entry)", "Part Number (ISF)", "Country of Origin Code (Entry)", "Country of Origin Code (ISF)", "HTS Code 1 (Entry)", "HTS Code 2 (Entry)", "HTS Code 3 (Entry)", "HTS Code (ISF)", "ISF Match", "PO Match", "Part Number Match", "COO Match", "HTS Match", "Exception Description"]
  end

  def add_exception_row sheet, row_number, column_widths, entry, invoice_line, tariff_lines, isf, isf_match
    row = []
    row << field(isf.try(:transaction_number), "")
    row << field(isf.try(:master_bill_of_lading), entry.split_master_bills_of_lading.join(", "))
    row << field(isf.try(:house_bills_of_lading), entry.split_house_bills_of_lading.join(", "))
    row << entry.broker_reference
    row << invoice_line.try(:product_line)
    row << invoice_line.try(:po_number)
    row << isf_match.try(:po)
    row << invoice_line.try(:part_number)
    row << isf_match.try(:style)
    row << invoice_line.try(:country_origin_code)
    row << isf_match.try(:coo)
    row << tariff_lines.try(:[], 0).try(:hts_code).to_s.hts_format
    row << tariff_lines.try(:[], 1).try(:hts_code).to_s.hts_format
    row << tariff_lines.try(:[], 2).try(:hts_code).to_s.hts_format
    row << isf_match.try(:hts).to_s.hts_format
    row << (isf.present? ? "Y" : "N")
    row << (isf_match.try(:po_match) ? "Y" : "N")
    row << (isf_match.try(:style_match) ? "Y" : "N")
    row << (isf_match.try(:coo_match) ? "Y" : "N")
    row << (isf_match.try(:hts_match) ? "Y" : "N")
    
    row << exception_notes(entry, invoice_line, tariff_lines, isf, isf_match)

    XlsMaker.add_body_row sheet, row_number, row, column_widths
  end

  def field isf_value, entry_value
    isf_value.presence || entry_value
  end

  def exception_notes entry, invoice_line, tariff_lines, isf, isf_match
    if isf.nil?
      message = "Unabled to find an ISF with a Broker Reference of '#{entry.broker_reference}' OR a Master Bill of '#{entry.master_bills_of_lading}'"
      house_bills = entry.split_house_bills_of_lading.join(", ")
      if house_bills.length > 0
        message << " OR a House Bill in '#{house_bills}'"
      end
       message << "."
       return message
    else
      if !isf_match.po_match
        return "Unable to find PO # '#{invoice_line.po_number}' on ISF '#{isf.transaction_number}'."
      elsif !isf_match.style_match
        return "Unable to find an ISF line with PO # '#{invoice_line.po_number}' and Part # '#{invoice_line.part_number}' on ISF '#{isf.transaction_number}'."
      elsif !isf_match.hts_match || !isf_match.coo_match
        message = "The ISF line with PO # '#{invoice_line.po_number}' and Part '#{invoice_line.part_number}'"
        suffix = ""
        if !isf_match.hts_match
          suffix << " did not match to HTS #{"#".pluralize(tariff_lines.length)} #{tariff_lines.map {|t| "'#{t.hts_code.to_s.hts_format}'"}.join(", ")}"
        end

        if !isf_match.coo_match
          suffix << " and" if suffix.length > 0
          suffix << " did not match to Country '#{invoice_line.country_origin_code}'"
        end

        return message + suffix + "."
      else
        return nil
      end
    end
  end

  def matches line, tariffs, isfs
    # basically, we're looking for a single line that as close as possible matches the invoice line / tariff...so what
    # we'll do is evaluate all the lines to see how well each of the criteria matches...and if we find a line that 
    # matches them all, we'll say it matches...if we don't fine one, then we'll return the best match
    matches = []

    catch(:found) do 
      isfs.each do |isf|
        isf.security_filing_lines.each do |isf_line|
          match = IsfMatch.new isf, isf_line

          match.hts_match = !tariffs.find { |t| match.hts[0..5] == t.hts_code.to_s.strip[0..5]}.nil?
          match.coo_match = match.coo.upcase == line.country_origin_code.to_s.strip.upcase
          match.po_match = match.po.upcase == line.po_number.to_s.strip.upcase
          match.style_match = match.style.upcase == line.part_number.to_s.strip.upcase

          matches << match

          # no use continuing to look for rows if all the criteria match
          throw(:found) if match.matches?
        end
      end
    end

    # Return the "most matched" result
    matches.sort!

    most_matched = matches.first

    # If the "most matched" result doesn't match on PO, then clear the isf values for style
    if !most_matched.po_match || !most_matched.style_match
      most_matched.coo, most_matched.hts, most_matched.style = ""
      most_matched.hts_match, most_matched.coo_match = false
    end

    if !most_matched.po_match
      most_matched.po = ""
      most_matched.style_match = false
    end
    

    most_matched
  end

  def full_match? matches_hash
    matches_hash.values.uniq.first == true
  end

  class IsfMatch
    attr_reader :isf
    attr_accessor :hts_match, :coo_match, :po_match, :style_match, :po, :style, :hts, :coo, :isf_line_number

    def initialize isf, isf_line
      @isf = isf
      @po = isf_line.po_number.to_s.strip
      @style = isf_line.part_number.to_s.strip
      @hts = isf_line.hts_code.to_s.strip
      @coo = isf_line.country_of_origin_code.to_s.strip
      @isf_line_number = isf_line.line_number
    end

    def <=> m
      # Evaluate whatever match has the most matches as the 
      v = m.match_count <=> match_count

      if v == 0
        v = m.isf_line_number <=> isf_line_number
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