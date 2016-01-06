require 'open_chain/report/sql_proxy_data_report'

module OpenChain; module Report; class AllianceDeferredRevenueReport
  include SqlProxyDataReport

  def self.permission? user
    (Rails.env=='development' || MasterSetup.get.system_code=='www-vfitrack-net') && user.in_group?(Group.use_system_group(IntacctErrorsController::VFI_ACCOUNTING_USERS, create: false))
  end

  def column_headers run_by, settings
    {'bf' => "Broker File #", 'ff' => "Freight File #", "bid" => "Brokerage Invoice Date", "c" => "Cust #", "dr" => "Deferred Revenue", "fid"=> "Freight Invoice Date"}
  end

  def get_data_conversions run_by, settings
    {'dr' => decimal_conversion}
  end

  def self.sql_proxy_query_name run_by, settings
    "deferred_revenue"
  end

  def self.sql_proxy_parameters run_by, settings
    # The params should come to us via the user as a YYYY-MM-DD string, which is fine, just strip the hyphens
    {start_date: format_date_string(settings['start_date'])}
  end

  def worksheet_name run_by, settings
    "Deferred Revenue"
  end

  def report_filename run_by, settings
    "Deferred Revenue On #{settings['start_date']}.xls"
  end

  def self.format_date_string ds
    return ds.to_s.gsub("-", "").strip
  end
  private_class_method :format_date_string


end; end; end;