module OpenChain; module Report; module BaseReportHelper
  extend ActiveSupport::Concern

    # Validates and returns a date string value suitable to be directly utilized in a SQL query string.
    # You'll want to specify a time zone in cases where the column you're reporting against is a Datetime
    # since the date selected is more than likely not expected to be UTC based (ie. db times)
    def sanitize_date_string dstr, time_zone_name = nil
      if time_zone_name
        ActiveSupport::TimeZone[time_zone_name].parse(dstr.to_s).to_s(:db)
      else
        Date.parse(dstr.to_s).strftime("%Y-%m-%d")
      end
    end

    # Removes outer quotes included by AR's .sanitize
    def sanitize str
      ActiveRecord::Base.sanitize(str).gsub(/(\A\')|(\'\z)/,"")
    end

    # Proxies protected method
    def sanitize_sql_array prepared_string, var_array
      ActiveRecord::Base.send(:sanitize_sql_array, [prepared_string, var_array])
    end

    def sanitize_string_in_list values
      values.map {|n| ActiveRecord::Base.connection.quote n }.join(", ")
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

    def transport_mode_us_ca_translation_lambda
      transport_modes = Entry.get_transport_mode_name_lookup_us_ca
      lambda { |result_set_row, raw_column_value| transport_modes[raw_column_value.to_i] }
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
      if conversions
        if column_name
          translation = conversions[column_name]
          translation ||= conversions[column_name.to_sym]
        end

        translation ||= conversions[column_number]
      end
      
      translation
    end

    # Executes a query against the read replica version of the database.  A result set is yielded.
    def execute_query query
      distribute_reads do
        yield ActiveRecord::Base.connection.execute(query)
      end
      nil
    end

    # Allows report results to be indexed by field name. field_map is a hash of name => index
    class RowWrapper
      attr_reader :field_map

      def initialize row, field_map
        @row = row
        @field_map = field_map
      end

      def to_a
        @row
      end

      def [](name)
        @row[field_map[name]]
      end

      def []=(name, value)
        @row[field_map[name]] = value
      end
    end
end; end; end;
