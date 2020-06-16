module OpenChain; module CustomHandler; module CsvFileParserSupport
  extend ActiveSupport::Concern

  def parse_csv_file csv_data, column_separator: ",", disable_quoting: false, starting_row: 0, additional_csv_opts: {}, skip_blank_rows: true
    csv_opts = { col_sep: column_separator }.merge additional_csv_opts
    # \007 turns the bell character into the quote char, which essentially turns off csv
    # because no character based data would ever have a bell char
    # There's no other way/option I could actually find that just disabled the quoting
    csv_opts[:quote_char] = "\007" if disable_quoting

    row_count = -1
    collected_rows = nil
    CSV.parse(csv_data, csv_opts) do |row|
      row_count += 1
      next if row_count < starting_row || (skip_blank_rows && blank_csv_row?(row))

      if block_given?
        yield row, row_count
      else
        collected_rows ||= []
        collected_rows << row
      end
    end

    collected_rows
  end

  def blank_csv_row? row
    return true if row.blank?
    row.each {|v| return false if v.present? }
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  # Returns the value using a starting index of 1,
  # this makes it less brain work to compare spec positions (which are almost always 1 indexed)
  # vs the actual zero based array indexes for the line
  def row_value row, index
    row[index - 1]
  end

end; end; end
