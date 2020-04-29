require 'api/v1/admin/admin_api_controller'

module Api; module V1; class SqlProxyPostbacksController < Api::V1::Admin::AdminApiController

  before_filter :require_admin

  def extract_results params, options = {}
    options = {null_response: {"OK" => ""}, yield_nil_results: false}.merge options
    # Params may be nil in cases where a query didn't return any results (rails munges JSON like {'results':[]} into {'results':nil}).
    # So don't return an error if results is there but it's null, just don't yield.
    if (params.include?("results") && params[:results].nil?) || (params[:results] && params[:results].respond_to?(:each))
      if params[:results] || options[:yield_nil_results]
        yield params[:results], params[:context]
      else
        render json: options[:null_response]
      end
    else
      render_error "Bad Request", :bad_request
    end
  end

  def receive_sql_proxy_report_data
    extract_results(params, {yield_nil_results: true}) do |results, context|
      # results could be nil if nothing was returned by the query...change it to a blank array then.
      results = [] if results.nil?

      # The actual report class and run by user id should be part of the context params.  We'll throw
      # an error locally if this is not so, it's a problem on our end not the SQL Proxy end so no need to
      # error back to it.
      id =  context["report_result_id"].to_i unless context["report_result_id"].blank?
      report_result = ReportResult.where(id: id).first

      if report_result && report_result.status.to_s.upcase == "RUNNING"
        report_result.delay.continue_sql_proxy_report results.to_json
      else
        StandardError.new("Unable to find ReportResult for id #{context["report_result_id"]}.").log_me
      end

      render json: {"OK" => ""}
    end
  end

end; end; end;