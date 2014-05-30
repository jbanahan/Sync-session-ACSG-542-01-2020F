module Api; module V1; class AllianceReportsController < SqlProxyPostbackController

  def receive_alliance_report_data
    extract_results(params, {yield_nil_results: true}) do |results, context|
      # results could be nil if nothing was returned by the query...change it to a blank array then.
      results = [] if results.nil?

      # The actual report class and run by user id should be part of the context params.  We'll throw 
      # an error locally if this is not so, it's a problem on our end not the SQL Proxy end so no need to 
      # error back to it.
      id =  context["report_result_id"].to_i unless context["report_result_id"].blank?
      report_result = ReportResult.where(id: id).first

      if report_result && report_result.status.to_s.upcase == "RUNNING"
        report_result.delay.continue_alliance_report results.to_json
      else
        StandardError.new("Unable to find ReportResult for id #{context["report_result_id"]}.").log_me
      end

      render json: {"OK" => ""}
    end
  end

end; end; end