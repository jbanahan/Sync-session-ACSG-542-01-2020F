require 'open_chain/alliance_parser'
require 'open_chain/report/alliance_webtracking_monitor_report'
require 'open_chain/custom_handler/kewill_entry_parser'
require 'open_chain/custom_handler/kewill_data_requester'

module Api; module V1; class AllianceDataController < SqlProxyPostbackController

  def receive_alliance_entry_details 
    # Really all we're doing here is just delaying off the processing of the params being posted
    extract_results (params) do |results, context|
      OpenChain::AllianceParser.delay.process_alliance_query_details results.to_json, context.to_json
      render json: {"OK" => ""}
    end
  end

  def receive_alliance_entry_tracking_details
    extract_results(params) do |results, context|
      OpenChain::Report::AllianceWebtrackingMonitorReport.delay.process_alliance_query_details results.to_json
      render json: {"OK" => ""}
    end
  end

  def receive_updated_entry_numbers
    extract_results(params) do |results, context|
      # There's really only going to be a single result returned here which is just a single has
      # The key is the entry file number that was updated, and the value is the time it was updated.
      results.each_pair do |k, v|
        OpenChain::CustomHandler::KewillDataRequester.delay.request_entry_data k, v
      end
      
      render json: {"OK" => ""}
    end
  end

  def receive_entry_data
    extract_results(params) do |results, context|
      begin
        s3_data = OpenChain::CustomHandler::KewillEntryParser.save_to_s3 results
        OpenChain::CustomHandler::KewillEntryParser.delay.process_from_s3 s3_data[:bucket], s3_data[:key]
      rescue => e
        e.log_me ["Failed to store entry file data for file # #{results.try(:[], 'entry').try(:[], 'file_no')}."]
      end
      
      # Even if we had an error, don't bother reporting back to the post that there was one, since we're already
      # recording it locally.
      render json: {"OK" => ""}
    end
  end

end; end; end