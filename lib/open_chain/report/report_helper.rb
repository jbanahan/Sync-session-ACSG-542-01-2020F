module OpenChain
  module Report
    module ReportHelper
      DATE_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD'
      DATE_TIME_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD HH:MM'
      CURRENCY_FORMAT = Spreadsheet::Format.new :number_format=>'#,##0.00'
      DATE_FORMAT_MMDDYY = Spreadsheet::Format.new :number_format=>'MM/DD/YYYY'

      # Writes the results of the query including headings into the sheet starting at cell A1
      # +sheet+ - the excel spreadsheet to output the query data into
      # +query+ - the query to execute
      # +data_converions+ - This hash param allows you define per column data translations.  Define a lambda
      # that receives 2 parameters, the full result set row array and the raw column value and the return value of the lambda
      # will be output into the excel cell.  Define the hash key as either the string/symbolized column name or as the
      # integer column number (the name key takes priority in case of collisions).
      def table_from_query sheet, query, data_conversions = {}
        result_set = ActiveRecord::Base.connection.execute query
        column_names = result_set.fields
        XlsMaker.add_header_row sheet, 0, column_names
        data_rows = write_result_set_to_sheet result_set, sheet, column_names, 1, data_conversions
        data_rows
      end

      def write_result_set_to_sheet result_set, sheet, column_names, row_number, data_conversions = {}
        column_widths = []
        initial_row = row_number
        result_set.each do |result_set_row|
          result_set_row.each_with_index do |raw_column_value, column_number|
            # Extract and translate the raw value from the database
            value = translate_raw_result_set_value(result_set_row, raw_column_value, column_number, column_names[column_number], data_conversions)

            # Write the value to the Excel sheet
            XlsMaker.insert_cell_value sheet, row_number, column_number, value, column_widths
          end
          row_number += 1
        end
        row_number - initial_row
      end

      def workbook_to_tempfile wb, prefix, opts = {}
        if block_given?
          Tempfile.open([prefix,'.xls']) do |t|
            t.binmode
            if opts[:file_name]
              Attachment.add_original_filename_method t
              t.original_filename = opts[:file_name]
            end
            wb.write t
            # Rewind to beginnging to IO stream so the tempfile can be read 
            # from the start
            t.rewind
            yield t
          end
        else
          t = Tempfile.new([prefix,'.xls'])
          if opts[:file_name]
            Attachment.add_original_filename_method t
            t.original_filename = opts[:file_name]
          end
          wb.write t.path
          t
        end
      end

      # Validates and returns a date string value suitable to be directly utilized in a SQL query string.
      # You'll want to specify a time zone in cases where the column you're reporting against is a Datetime
      # since the date selected is more than likely not expected to be UTC based (ie. db times)
      def sanitize_date_string dstr, time_zone_name = nil
        d = Date.parse(dstr.to_s)
        if time_zone_name
          # This translates to the time in the zone specified and then returns a datetime string converted to the 
          # db timezone suitable to be directly placed into a query.
          Time.use_zone(time_zone_name) do
            d = d.to_time_in_current_zone.in_time_zone(OpenChain::Application.config.time_zone).to_s(:db)
          end
          d
        else
          d.strftime("%Y-%m-%d")
        end
      end

      def datetime_translation_lambda target_time_zone_name, convert_to_date = false
        time_zone = ActiveSupport::TimeZone[target_time_zone_name]
        lambda { |result_set_row, raw_column_value|
          time = nil
          if raw_column_value
            time = raw_column_value.in_time_zone time_zone
            if convert_to_date
              time = time.to_date
            end
          end
          time
        }
      end

      # This lambda will translate and id (int) value to the excel URL to use for viewing a
      # core module object.
      def weblink_translation_lambda core_module
        lambda { |result_set_row, raw_column_value|
          url = core_module.klass.excel_url raw_column_value
          XlsMaker.create_link_cell url
        }
      end

      def csv_translation_lambda join_string = ", ", split_expression = /\n\s*/
        lambda { |result_set_row, raw_column_value|
          if raw_column_value.blank?
            raw_column_value
          else
            raw_column_value.split(split_expression).join(join_string)
          end
        }
      end

    private 

      # Takes the raw result set value from the query and conditionally does some data manipulation on it.
      # By default, it handles timezone conversions in Datetime columns and nothing else.  See the data_conversions param
      # on the table_from_query method for how to do more fine-grained data manipulations.
      def translate_raw_result_set_value result_set_row, raw_column_value, column_number, column_name, data_conversions
        conversion_lambda = get_data_conversion data_conversions, column_number, column_name
        value = nil
        if conversion_lambda
          value = conversion_lambda.call result_set_row, raw_column_value
        else
          value = default_translate raw_column_value
        end

        value
      end

      # Translates the value from a raw SQL datatype into a format that 
      # should be able to be handled in writing to the excel file (see XlsMaker#insert_cell_value)
      def default_translate value
        if value.is_a?(Time)
          # Since we're parsing a raw SQL connection here, we're not actually getting the benefit of the Timezone translation
          # that ActiveRecord normally provides.  So we'll have to handle that here.
          value = value.in_time_zone(Time.zone)
        end
        value
      end

      def get_data_conversion conversions, column_number, column_name
        translation = nil
        if column_name
          translation = conversions[column_name]
          translation ||= conversions[column_name.to_sym]
        end

        translation ||= conversions[column_number]

        translation
      end
    end
  end
end
