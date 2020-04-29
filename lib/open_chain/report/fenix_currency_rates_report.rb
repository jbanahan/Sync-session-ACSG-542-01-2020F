require 'open_chain/report/sql_proxy_data_report'
require 'open_chain/fenix_sql_proxy_client'

module OpenChain; module Report; class FenixCurrencyRatesReport
  include SqlProxyDataReport

  def self.schedulable_settings user, report_name, opts
    # Regardless of the schedule source,
    # return start_date of the previous day.
    settings = {}
    settings['start_date'] = (Time.zone.now.in_time_zone(user.time_zone) - 1.day).to_date.to_s

    friendly_settings = ["Exchange Rate Updated On or After #{settings['start_date']}"]

    {settings: settings, friendly_settings: friendly_settings}
  end

  def self.permission? user
    (Rails.env.development? || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
  end

  def column_headers run_by, settings
    {'c' => "Country", 'cn' => "Name", "cur" => "Currency", "der" => "Exchange Date", "er" => "Exchange Rate"}
  end

  def get_data_conversions run_by, settings
    {
      'der' => fenix_date_conversion,
      'er' => decimal_conversion(decimal_places: 6),
    }
  end

  def self.sql_proxy_query_name run_by, settings
    "fenix_currency_rate_report"
  end

  def self.sql_proxy_parameters run_by, settings
    params = {}
    if !settings['start_date'].blank?
      params['start_date'] = format_date_string(settings['start_date'])
    end

    if !settings['end_date'].blank?
      params['end_date'] = format_date_string(settings['end_date'])
    end

    if !settings['countries'].blank?
      if settings['countries'].is_a? String
        params['countries'] = settings['countries'].split(/\n */)
      elsif settings['countries'].respond_to?(:map)
        params['countries'] = settings['countries'].map {|c| c.to_s}
      else
        # This is mostly just for backend setup use, as the value will always be string coming from the user screen.
        raise "Invalid countries list.  Must be a string with countries on each line or an enumerable object."
      end
    end

    raise "A start date must be present." if params['start_date'].nil?

    params
  end

  def fenix_date_conversion
    # The date values are returned as strings and they are only Date values (the time component is always zero in Fenix)
    # ..so just parse them and return them as dates
    lambda { |result_set_row, raw_column_value|
      Time.zone.parse(raw_column_value).try(:to_date)
    }
  end

  def worksheet_name run_by, settings
    "CA Currency Rates"
  end

  def report_filename run_by, settings
    "CA Currency Rates On #{settings['start_date']}.xls"
  end

  def self.format_date_string ds
    return ds.to_s.gsub("-", "").strip
  end
  private_class_method :format_date_string

  def self.sql_proxy_client
    OpenChain::FenixSqlProxyClient.new
  end

end; end; end;