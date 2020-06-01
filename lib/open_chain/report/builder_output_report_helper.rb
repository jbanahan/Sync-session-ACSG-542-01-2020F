require 'open_chain/report/base_report_helper'

module OpenChain; module Report; module BuilderOutputReportHelper
  include OpenChain::Report::BaseReportHelper

  # Return the zero indexed starting column number to use when outputting query columns to a builder.
  # This allows you to return something like a id in the query as the first column, but then not actually output it to the file.
  def query_column_offset
    0
  end

  # If you override this method to return true, then the values returned from any data conversions will be placed back into the result
  # set and can be referenced by conversions that run after it.  This can be useful, for instance, if you have something like an id
  # column and you write a conversion to look up the object.  If you allow the conversion to be placed back into the result set, then
  # any column conversions running after the initial one (conversions are run based on column order of the result set), can reference
  # the object without having to look it up again.
  def data_conversions_modify_result_set?
    true
  end

  # If you want to supply the full listing of column names here, rather than via query column aliases, override this
  # method and return an array of strings.  The array length should match the result set column length, meaning if you
  # utilze the query_column_offset, you need to still include the column name for those starting columns that were eliminated
  # from the builer output.
  def column_names
    nil
  end

  # This should be an array of styles to utilize on the builder body output.  The array indexes should match the columns you actually
  # intend on output to the builder.  In other words, if you're using the query_column_offset, do not include array indexes for any
  # columns you intend to skip
  def column_styles
    nil
  end

  def generate_results_to_tempfile query, output_format, sheet_name, report_filename_base, data_conversions: {}, &block
    b = builder(output_format)
    sheet = b.create_sheet sheet_name
    write_query_results_to_tempfile(b, sheet, query, report_filename_base, data_conversions: data_conversions, &block)
  end

  def write_query_results_to_tempfile builder, sheet, query, report_filename_base, data_conversions: {}, &block
    write_query_to_builder builder, sheet, query, data_conversions: data_conversions
    write_builder_to_tempfile(builder, report_filename_base, &block)
  end

  def write_builder_to_tempfile builder, report_filename_base
    report_filename = Attachment.get_sanitized_filename("#{report_filename_base}.#{file_extension(builder)}")

    tempfile_params = [self.class.name.demodulize, builder.output_format.to_s]
    if block_given?
      Tempfile.open(tempfile_params) do |temp|
        setup_tempfile_setup(temp, builder, report_filename)

        yield temp
      end
    else
      temp = Tempfile.open(tempfile_params)
      setup_tempfile_setup(temp, builder, report_filename)
      return temp
    end
    nil
  end

  def setup_tempfile_setup temp, builder, report_filename
    builder.write temp
    temp.flush
    temp.rewind

    Attachment.add_original_filename_method(temp, report_filename)
    nil
  end

  def write_query_to_builder builder, sheet, query, data_conversions: {}
    execute_query(query) do |result_set|
      write_result_set_to_builder(builder, sheet, result_set, data_conversions: data_conversions)
    end
  end

  def write_result_set_to_builder builder, sheet, result_set, data_conversions: {}
    write_header_row(builder, sheet, _column_names(result_set, query_column_offset))
    builder.freeze_horizontal_rows sheet, 1
    write_report_body_rows(builder, sheet, result_set, data_conversions: data_conversions)
  end

  def write_header_row builder, sheet, column_names
    builder.add_header_row sheet, column_names
  end

  def write_body_row builder, sheet, row, styles: nil
    builder.add_body_row sheet, row, styles: styles
  end

  def write_report_body_rows builder, sheet, result_set, data_conversions: {}
    starting_column_number = query_column_offset
    styles = column_styles

    all_column_names = _column_names(result_set, 0)
    result_set.each do |result_set_row|
      row_output = []

      result_set_row.each_with_index do |raw_column_value, column_number|

        # Extract and translate the raw value from the database
        # Don't use the offset here, since the translation is generally going to reach into the actual returned query result row and we want to
        # provide the actual column from the result set we're parsing (as opposed to the intended output column number for the value)
        value = translate_raw_result_set_value(result_set_row, raw_column_value, column_number, all_column_names[column_number], data_conversions)

        # If specified, put the translated value back into the result set row so it can be referenced by other translations
        if data_conversions_modify_result_set?
          result_set_row[column_number] = value
        end

        # The reason we're not skipping over the column at the top of the loop is because it's possible
        # that even if you're skipping the columns in the output, you may wish to still translate the values
        # for later use in another conversion.
        next if column_number < starting_column_number

        row_output << value
      end
      write_body_row(builder, sheet, row_output, styles: styles) if row_output.present?
    end
  end

  # This lambda will translate and id (int) value to the excel URL to use for viewing a
  # core module object.
  def weblink_translation_lambda builder, core_object_class
    lambda do |_result_set_row, raw_column_value|
      url = core_object_class.excel_url raw_column_value
      builder.create_link_cell url
    end
  end

  def _column_names result_set, offset
    names = column_names.presence || result_set.fields
    raise "Failed to discover column names." if names.blank?
    names[offset..-1]
  end

  def builder output_format
    case output_format.to_s.downcase
    when "csv"
      CsvBuilder.new
    when "xls"
      XlsBuilder.new
    else
      XlsxBuilder.new
    end
  end

  def file_extension builder
    builder.output_format.to_s
  end

end; end; end
