module Api; module V1; class AllianceReportsController < SqlProxyPostbacksController

  # This method exists solely for legacy purposes...once all sql proxy instances have been updated to remove this postback
  # handler, then 
  def receive_alliance_report_data
    receive_sql_proxy_report_data
  end

end; end; end