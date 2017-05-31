require 'open_chain/kewill_sql_proxy_client'
require 'open_chain/report/report_helper'

module OpenChain; module Report; module SqlProxyDataReport
  extend ActiveSupport::Concern
  include ReportHelper 
  
  def table_from_sql_proxy_query sheet, results, column_headers, data_conversions = {}
    # The query results are pretty much just a straight JSON'ized ActiveRecord query result set (Rails 4 version).
    # This ends up being an array containing hash objects for each result row.  
    # The hash key is the column name (downcased for some reason - active record'ism?) and the value is obviously the query value for the column.

    # Nil can be posted back for the results if nothing is found..
    results = [] if results.nil?

    fake_result_set = Enumerator.new(results.length) do |yielder|
      results.each do |row|
        yielder.yield row.values
      end
    end

    XlsMaker.add_header_row sheet, 0, column_headers.values

    # Column header is a map of the raw query column names from sql_proxy result to the actual column headers you want in the report.
    # We can just pull the keys from it, since we're expecting the caller to have passed the headers in the output order
    write_result_set_to_sheet fake_result_set, sheet, column_headers.keys, 1, data_conversions
  end

  def alliance_date_conversion 
    # Alliance dates should come across to us as YYYYMMDD (either as a string or a numeric)
    lambda do |result_set_row, raw_column_value|
      # Dates in Alliance are stored as numbers...which, depending on how we format the query, 
      # can be returned as strings or numbers (BigDecimals).  These will never have any 
      # decimal components, so just take the integer value and then to_s it if the value is numeric
      value = raw_column_value.is_a?(Numeric) ? raw_column_value.to_i.to_s : raw_column_value.to_s
      (value.blank? || value =~ /^0+$/) ? nil : Date.parse(value)
    end
  end

  def decimal_conversion decimal_offset: 0, decimal_places: 2
    # One of the quirks of transfering active record results over json is that all decimal values 
    # are turned into Strings - since javascript handles decimal values like ruby handles floats (inexactly)
    lambda do |row, value|
      v = value.to_s
      if decimal_offset > 0
        # Strip any trailing decimal and zeros (.ie "10.0")
        v = v.sub(/\.0*$/, "")
        v = v.rjust(decimal_offset, '0')
        if decimal_offset == v.length
          v = "0.#{v}"
        else
          decimal_position = v.length - decimal_offset
          v = v[0, decimal_position] + "." + v[decimal_position..-1]
        end
      end

      v = v.blank? ? nil : BigDecimal.new(v).try(:round, decimal_places)
    end
  end

  # This method receives the posted results of a sql_proxy query and turns them into a spreadsheet
  # returning the data as a tempfile.  
  def process_results run_by, results, settings
    # This is going to be the main method to extend if you need to make any major adjustments to how you process the query results
    # returned by the sql_proxy query.

    # If you don't override this method, then you must implement the folowing methods: column_headers, worksheet_name, report_filename_prefix
    sheet_name = worksheet_name run_by, settings
    wb = XlsMaker.create_workbook sheet_name
    sheet = wb.worksheets.find {|s| s.name == sheet_name}

    conversions = self.respond_to?(:get_data_conversions) ? get_data_conversions(run_by, settings) : {}

    table_from_sql_proxy_query sheet, results, column_headers(run_by, settings), conversions

    filename = report_filename(run_by, settings)
    tf = workbook_to_tempfile wb, filename
    Attachment.add_original_filename_method tf, filename

    tf
  end

  module ClassMethods
    def sql_proxy_report?
      true
    end

    # Override this if you need a more complex constructor call
    def new_instance run_by, results, settings = {}
      self.new
    end

    def process_sql_proxy_query_details run_by, results, settings
      new_instance(run_by, results, settings).process_results run_by, results, settings
    end

    def run_report run_by, settings
      raise "#{self.name} must implement the method 'sql_proxy_query_name'." unless self.respond_to?(:sql_proxy_query_name)

      # This is solely for testing purposes...
      client = settings['sql_proxy_client'].nil? ?  sql_proxy_client : settings['sql_proxy_client']

      # Fill in the report class value so the postback controller knows which report to pass the results back to
      query_context = {'report_result_id' => settings['report_result_id']}

      # By default, just pass the settings value straight to the sql proxy call (this implies that your query params in sql proxy
      # match exactly with the settings keys and the values are the expected datatypes in the sql_proxy query)
      parameters = nil
      if self.respond_to?(:sql_proxy_parameters)
        parameters = self.sql_proxy_parameters(run_by, settings)
      else
        # The sql_proxy query call will fail if there are parameters that are unaccounted for in the settings hash
        # In order to keep API parity w/ the standard reporting interface I also don't want to add another method parameter.
        # So, just remove any keys that we might be adding here (or we know will be passed in) from the settings as the 
        # default path (anything more complex can easily be done w/ a simple method implementation)
        parameters = settings.dup
        parameters.delete 'report_result_id'
        parameters.delete 'sql_proxy_client'
      end

      # This ends the first part of the report by posting the query data to the sql_proxy.  sql_proxy will then post the 
      # sql results back as json to the SqlProxyPostbacksController class...which then passes control through to 
      # the ReportResult#continue_sql_proxy_report method (and from there to process_sql_proxy_query_details)
      client.report_query self.sql_proxy_query_name(run_by, settings), parameters, query_context
    end

    def sql_proxy_client
      OpenChain::KewillSqlProxyClient.new
    end

  end

end; end; end;

