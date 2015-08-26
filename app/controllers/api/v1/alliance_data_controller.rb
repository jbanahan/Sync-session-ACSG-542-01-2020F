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
      run_in_thread do 
        # Split the results into groups of 1000 (to avoid overflowing the max size of a delayed job handler column)
        results.keys.in_groups_of(batch_size, false) do |keys|
          sub_results = {}
          keys.each {|k| sub_results[k] = results[k] }
          OpenChain::CustomHandler::KewillDataRequester.delay.request_entry_batch_data sub_results
        end
      end
      render json: {"OK" => ""}
    end
  end

  def receive_entry_data
    extract_results(params) do |results, context|
      run_in_thread do
        begin
          s3_data = OpenChain::CustomHandler::KewillEntryParser.save_to_s3 results
          # the data may be nil if a request was made for a file that didn't exist or soemthing like that...the save_to_s3
          # figures all that out and we can rely on its return value to determine if we need to proc anything or not
          if s3_data
            OpenChain::CustomHandler::KewillEntryParser.delay.process_from_s3 s3_data[:bucket], s3_data[:key]
          end
        rescue => e
          e.log_me ["Failed to store entry file data for file # #{results.try(:[], 'entry').try(:[], 'file_no')}."]
        end
      end
      
      # Even if we had an error, don't bother reporting back to the post that there was one, since we're already
      # recording it locally.
      render json: {"OK" => ""}
    end
  end

  private 

    def run_in_thread
      # Run inline for testing
      if Rails.env.test?
        yield
      else
        Thread.new do
          #need to wrap connection handling for safe threading per: http://bibwild.wordpress.com/2011/11/14/multi-threading-in-rails-activerecord-3-0-3-1/
          ActiveRecord::Base.connection_pool.with_connection do
            yield
          end
        end
      end
    end

    def batch_size
      # Method exists purely for mocking/test purposes
      1000
    end

end; end; end