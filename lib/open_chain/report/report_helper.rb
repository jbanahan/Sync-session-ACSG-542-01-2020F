require 'spreadsheet'
require 'open_chain/report/base_report_helper'

module OpenChain
  module Report
    module ReportHelper
      include OpenChain::Report::BaseReportHelper

      DATE_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD'
      DATE_TIME_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD HH:MM'
      CURRENCY_FORMAT = Spreadsheet::Format.new :number_format=>'#,##0.00'
      DATE_FORMAT_MMDDYY = Spreadsheet::Format.new :number_format=>'MM/DD/YYYY'
      PERCENTAGE_FORMAT = Spreadsheet::Format.new :number_format=>'0.00%'

      # Writes the results of the query including headings into the sheet starting at cell A1
      # +sheet+ - the excel spreadsheet to output the query data into
      # +query+ - the query to execute
      # +data_converions+ - This hash param allows you define per column data translations.  Define a lambda
      # that receives 2 parameters, the full result set row array and the raw column value and the return value of the lambda
      # will be output into the excel cell.  Define the hash key as either the string/symbolized column name or as the
      # integer column number (the name key takes priority in case of collisions).
      def table_from_query sheet, query, data_conversions = {}, opts = {}
        result_set = ActiveRecord::Base.connection.execute query
        table_from_query_result sheet, result_set, data_conversions, opts
      end

      # opt[:column_names] is required if result_set is not a Mysql2::Result
      def table_from_query_result sheet, result_set, data_conversions = {}, opts = {}
        starting_column_number = opts[:query_column_offset].to_i > 0 ? opts[:query_column_offset] : 0
        column_names = opts[:column_names] ? opts[:column_names] : result_set.fields[starting_column_number..-1]
        all_column_names = opts[:column_names] ? opts[:column_names] : result_set.fields
        header_row = opts[:header_row].presence || 0

        XlsMaker.add_header_row sheet, header_row, column_names
        data_rows = write_result_set_to_sheet result_set, sheet, all_column_names, header_row + 1, data_conversions, opts
        data_rows
      end

      def write_result_set_to_sheet result_set, sheet, column_names, row_number, data_conversions = {}, opts = {}
        column_widths = []
        initial_row = row_number

        # Allows us to add things like an id at the front of the query and instruct the result set writer to skip it.
        starting_column_number = opts[:query_column_offset].to_i > 0 ? opts[:query_column_offset] : 0

        result_set.each do |result_set_row|
          result_set_row.each_with_index do |raw_column_value, column_number|
            # Extract and translate the raw value from the database
            # Don't use the offset here, since the translation is generally going to reach into the actual returned query result row and we want to 
            # provide the actual column from the result set we're parsing (as opposed to the intended output column number for the value)
            value = translate_raw_result_set_value(result_set_row, raw_column_value, column_number, column_names[column_number], data_conversions)

            # If specified, put the translated value back into the result set row so it can be referenced by other translations
            if opts[:translations_modify_result_set] == true
              result_set_row[column_number] = value
            end

            # The reason we're not skipping over the column at the top of the loop is because it's possible
            # that even if you're skipping the columns in the output, you may wish to still translate the values
            # for later use in another conversion.
            next if column_number < starting_column_number

            # Write the value to the Excel sheet
            XlsMaker.insert_cell_value sheet, row_number, column_number - starting_column_number, value, column_widths
          end
          row_number += 1
        end
        row_number - initial_row
      end

      def xlsx_workbook_to_tempfile wb, prefix, opts={}, &proc
        write_tempfile wb, prefix, '.xlsx', opts, proc
      end

      def workbook_to_tempfile wb, prefix, opts={}, &proc
        write_tempfile wb, prefix, '.xls', opts, proc
      end

      def pdf_to_tempfile doc, prefix, opts={}, &proc
        write_tempfile doc, prefix, '.pdf', opts, proc
      end

      # This lambda will translate and id (int) value to the excel URL to use for viewing a
      # core module object.
      def weblink_translation_lambda core_module
        lambda { |result_set_row, raw_column_value|
          url = core_module.klass.excel_url raw_column_value
          XlsMaker.create_link_cell url
        }
      end

    private 

      def write_tempfile obj, prefix, ext, opts={}, proc
        if proc
          Tempfile.open([prefix, ext]) do |t|
            t.binmode
            if opts[:file_name]
              Attachment.add_original_filename_method t
              t.original_filename = opts[:file_name]
            end
            obj.respond_to?(:write) ? (obj.write t) : (obj.render t)
            # Rewind to beginning to IO stream so the tempfile can be read 
            # from the start
            t.flush
            t.rewind
            proc.call t
          end
        else
          t = Tempfile.new([prefix, ext])
          if opts[:file_name]
            Attachment.add_original_filename_method t
            t.original_filename = opts[:file_name]
          end
          obj.respond_to?(:write) ? (obj.write t) : (obj.render t)
          t.flush
          t
        end
      end

    end
  end
end
