require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftKewillAccountingReport5001
  include OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/arprfsub", "www-vfitrack-net/arprfsub"]
  end

  def self.parse file_content, opts = {}
    self.new.parse_file file_content
  end

  def parse_file file_content
    subsections = split_lines_by_subsection file_content, "^VANDEGRIFT FORWARDING CO., INC.                       "

    wb = XlsMaker.new_workbook
    make_data_tab wb, subsections

    if subsections.length > 0 && subsections[0].length >= 6
      make_parameters_tab wb, subsections[0]
    end

    send_email wb, 'ARPRFSUB', 'Alliance Report 5001 - ARPRFSUB', 'vsicilia@vandegriftinc.com'
  end

  private

  def send_email workbook, file_name_prefix, subject, to_addr
    Tempfile.open([file_name_prefix, ".xls"]) do |outbound_file|
      Attachment.add_original_filename_method outbound_file, "#{file_name_prefix}_#{Time.zone.now.strftime("%Y-%m-%d")}.xls"
      workbook.write outbound_file
      outbound_file.flush
      outbound_file.rewind

      body_text = "Attached is a Kewill-based report."
      OpenMailer.send_simple_html(to_addr, subject, body_text, [outbound_file]).deliver!
    end
  end

  def make_parameters_tab wb, section
    sheet = XlsMaker.create_sheet wb, "Parameters", []
    XlsMaker.add_body_row sheet, 0, [section[0].strip]
    XlsMaker.add_body_row sheet, 1, [section[1].strip]
    XlsMaker.add_body_row sheet, 2, [section[2].strip]
    XlsMaker.add_body_row sheet, 3, [section[3].strip]
    XlsMaker.add_body_row sheet, 4, [section[4].strip]
    XlsMaker.add_body_row sheet, 5, [section[5].strip]
    XlsMaker.add_body_row sheet, 6, [section[6].strip]
  end

  def split_lines_by_subsection data, header_line_match_text
    subsections = []
    current_subsection_lines = nil
    StringIO.new(data).each do |line|
      if line.match(header_line_match_text)
        current_subsection_lines = []
        subsections << current_subsection_lines
      end
      if line.strip.length > 0 && current_subsection_lines
        current_subsection_lines << line
      end
    end
    subsections
  end

  def make_data_tab wb, subsections
    total_section = Hash.new(0)
    sheet = XlsMaker.create_sheet wb, "Data", ['File Number', 'Master Bill', 'Div',
      'Inv Date', 'Open A/R', 'Open A/P', 'Total A/R-', 'Total A/P=', 'Profit',
      'Bill To']
    outbound_row_number = 1

    subsections.each do |section|
      inbound_row_number = 0
      section.each do |input_line|
        if inbound_row_number > 9
          if file_row?(input_line) && customer_present?(input_line)
            output_line = []

            # We are setting these to variables to make calculations easier.
            # We #to_s on these just in case that 'field' is non-existent.
            file_number = input_line[0..23].to_s.strip
            master_bill = input_line[25..38].to_s.strip
            div = input_line[39..43].to_s.strip
            inv_date = input_line[45..53].to_s.strip
            open_ar = input_line[55..66].to_s.strip
            open_ap = input_line[68..79].to_s.strip
            total_ar = input_line[81..92].to_s.strip
            total_ap = input_line[94..105].to_s.strip
            profit = input_line[107..118].to_s.strip
            bill_to = input_line[120..131].to_s.strip

            # Let's get the values as plain decimals here so we can use them all over
            dec_open_ar = string_to_decimal(open_ar)
            dec_open_ap = string_to_decimal(open_ap)
            dec_total_ar = string_to_decimal(total_ar)
            dec_total_ap = string_to_decimal(total_ap)
            dec_profit = string_to_decimal(profit)

            # Next we will do calculations. We use a custom method to convert
            # to decimals since accounting is weird.
            total_section['open_ar'] += dec_open_ar
            total_section['open_ap'] += dec_open_ap
            total_section['total_ar'] += dec_open_ar
            total_section['total_ap'] += dec_total_ap
            total_section['profit'] += dec_profit

            # Setup the output line
            output_line = [file_number, master_bill, div, inv_date, dec_open_ar,
              dec_open_ap, dec_total_ar, dec_total_ap, dec_profit, bill_to]

            XlsMaker.add_body_row sheet, outbound_row_number, output_line
            outbound_row_number += 1
          end
        end

        inbound_row_number += 1
      end
    end

    # Let's add the Grand Totals row
    company_totals = ["Grand Totals", "", "", "", total_section['open_ar'],
      total_section['open_ap'], total_section['total_ar'], total_section['total_ap'],
      total_section['profit']]
    XlsMaker.add_body_row sheet, outbound_row_number, company_totals
  end

  def string_to_decimal string
    value = if string.match("\-$")
      -(string.to_d.abs)
    else
      string.to_d
    end

    value
  end

  def file_row? line
    stripped_line = line[0..23].strip
    stripped_line.present? && stripped_line.scan(/\D+/).blank?
  end

  def customer_present? line
    line[120..131].to_s.strip
  end
end; end; end; end
