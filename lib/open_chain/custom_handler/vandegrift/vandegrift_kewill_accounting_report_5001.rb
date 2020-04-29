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
    parameters, title_layout, data_lines = split_file(file_content)
    wb = output_builder()

    make_data_tab wb, title_layout, data_lines

    if !parameters.blank?
      make_parameters_tab wb, parameters
    end

    send_email wb, 'ARPRFSUB', 'Alliance Report 5001 - ARPRFSUB', 'vsicilia@vandegriftinc.com'
  end

  def send_email workbook, file_name_prefix, subject, to_addr
    Tempfile.open([file_name_prefix, ".xlsx"]) do |outbound_file|
      Attachment.add_original_filename_method outbound_file, "#{file_name_prefix}_#{Time.zone.now.strftime("%Y-%m-%d")}.xlsx"
      workbook.write outbound_file
      outbound_file.flush
      outbound_file.rewind

      body_text = "Attached is a Kewill-based report."
      OpenMailer.send_simple_html(to_addr, subject, body_text, [outbound_file]).deliver_now
    end
  end

  def split_file file_content
    all_lines = StringIO.new(file_content).each_line.to_a
    parameters = extract_parameters(all_lines)
    title_layout = extract_title_layout(all_lines)
    data_lines = extract_data_lines(all_lines, title_layout)

    [parameters, title_layout, data_lines]
  end

  def extract_parameters lines
    parameters = []

    lines.each_with_index do |line, idx|
      if line =~ /ARPRFSUM-D0/
        parameters = lines[idx..(idx + 6)].map &:strip
        break
      end
    end

    parameters
  end

  def extract_title_layout lines
    title_layout = {}
    lines.each_with_index do |line, idx|
      if line =~ /Open A\/R/i && line =~ /Open A\/P/i
        title_layout = column_positions_hash(line, lines[idx + 1])
        break
      end
    end

    title_layout
  end

  def extract_data_lines lines, title_layout
    data_lines = []
    lines.each do |line|
      next unless title_layout["File Number"] && title_layout["Inv Date"]

      if line[title_layout["File Number"]].to_s.strip =~ /^\d+/ && line[title_layout["Inv Date"]].to_s.strip =~ /\d{2}\/\d{2}\/\d{2}/
        data_lines << line
      end
    end

    data_lines
  end

  def make_parameters_tab wb, parameters
    sheet = wb.create_sheet("Parameters")
    parameters.each do |p|
      wb.add_body_row(sheet, [p.to_s.strip])
    end

    nil
  end

  def make_data_tab wb, column_positions, lines
    sheet = wb.create_sheet("Data", headers: ['File Number', 'Master Bill', 'Div',
      'Inv Date', 'Open A/R', 'Open A/P', 'Total A/R-', 'Total A/P=', 'Profit',
      'Bill To'])
    wb.freeze_horizontal_rows(sheet, 1)

    total_section = Hash.new(BigDecimal("0"))

    lines.each do |input_line|
      # We are setting these to variables to make calculations easier.
      # We #to_s on these just in case that 'field' is non-existent.
      file_number = input_line[column_positions["File Number"]].to_s.strip
      master_bill = input_line[column_positions["Master Bill"]].to_s.strip
      div = input_line[column_positions["Div"]].to_s.strip
      inv_date = input_line[column_positions["Inv Date"]].to_s.strip
      open_ar = input_line[column_positions["Open A/R"]].to_s.strip
      open_ap = input_line[column_positions["Open A/P"]].to_s.strip
      total_ar = input_line[column_positions["Total A/R"]].to_s.strip
      total_ap = input_line[column_positions["Total A/P"]].to_s.strip
      profit = input_line[column_positions["Profit"]].to_s.strip
      bill_to = input_line[column_positions["Bill To"]].to_s.strip

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

      wb.add_body_row sheet, output_line
    end

    # Let's add the Grand Totals row
    company_totals = ["Grand Totals", "", "", "", total_section['open_ar'],
      total_section['open_ap'], total_section['total_ar'], total_section['total_ap'],
      total_section['profit']]
    wb.add_body_row(sheet, company_totals)
    nil
  end

  def string_to_decimal string
    value = if string.match("\-$")
      BigDecimal(string) * BigDecimal("-1")
    else
      BigDecimal(string)
    end

    value
  end

  def column_positions_hash title_line, dash_line
    title_hash = {}

    ["File Number", "Master Bill", "Div", "Inv Date", "Bill To"].each do |title|
      found = title_line.index(title)
      raise "Failed to find title position of title '#{title}'." if found.nil?

      title_hash[title] = find_column_positions(found, dash_line)
    end

    ["Open A/R", "Open A/P", "Total A/R", "Total A/P", "Profit"].each do |title|
      found = title_line.index(title)

      raise "Failed to find title position of title '#{title}'." if found.nil?

      title_hash[title] = find_column_positions(found, dash_line, numeric_column: true)
    end

    title_hash
  end

  def find_column_positions title_start, dash_line, numeric_column: false
    return nil if dash_line[title_start] != "-"

    # Find how many spacings prior to the title start and after the title start there are
    # Then we can construct a range to use to determine the where the data we're looking for
    # is in the file
    dash_length = 0
    (title_start..(dash_line.length - 1)).each do |idx|
      if dash_line[idx] != "-"
        break
      else
        dash_length += 1
      end
    end

    # Now work backwards and see if there's any other positions to get
    previous_dash = 0
    (0..(title_start - 1)).reverse_each do |idx|
      if dash_line[idx] != "-"
        break
      else
        previous_dash += 1
      end
    end

    start_position = (title_start - previous_dash)
    end_position = (title_start + (dash_length - 1))

    if numeric_column
      end_position += 1
    end

    (start_position..end_position)
  end

  def output_builder
    XlsxBuilder.new
  end

end; end; end; end
