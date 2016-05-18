require 'open_chain/report/sql_proxy_data_report'

module OpenChain; module Report; class KewillCurrencyRatesReport
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
    {'c' => "Country", 'cn' => "Name", "cur" => "Currency", "der" => "Exchange Date", "er" => "Exchange Rate", "ct"=> "Currency Type", "not" => "Remarks"}
  end

  def get_data_conversions run_by, settings
    {
      'der' => alliance_date_conversion,
      'er' => decimal_conversion(decimal_offset: 6, decimal_places: 6),
      'ct' => currency_type_conversion
    }
  end

  def self.sql_proxy_query_name run_by, settings
    "kewill_currency_rate_report"
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

  def worksheet_name run_by, settings
    "Currency Rates"
  end

  def report_filename run_by, settings
    "Currency Rates On #{settings['start_date']}.xls"
  end

  def currency_type_conversion
    lambda do |row, value|
      case value.to_s.upcase
      when "Q"
        "Quarterly"
      when "D"
        "Daily"
      else
        "None"
      end
    end
  end

  def self.format_date_string ds
    return ds.to_s.gsub("-", "").strip
  end
  private_class_method :format_date_string


end; end; end;