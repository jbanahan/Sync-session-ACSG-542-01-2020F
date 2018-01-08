require 'open_chain/report/alliance_webtracking_monitor_report'
require 'open_chain/custom_handler/kewill_data_requester'

module Api; module V1; class AllianceDataController < SqlProxyPostbacksController

  def receive_alliance_entry_tracking_details
    extract_results(params) do |results, context|
      OpenChain::Report::AllianceWebtrackingMonitorReport.delay.process_alliance_query_details results.to_json
      render_ok
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
      render_ok
    end
  end

  def receive_mid_updates 
    extract_results(params) do |results, context|
      # results should be an array
      run_in_thread do
        # Only do 100 of these at a time...there shouldn't be more than that many, but we don't want to overflow the delayed job
        # handler field with the values.
        results.in_groups_of(100, false) do |mids|
          ManufacturerId.delay.load_mid_records mids
        end
      end

      render_ok
    end
  end

  def receive_address_updates 
    extract_results(params) do |results, context|
      # results should be an array
      run_in_thread do
        # Only do 100 of these at a time...there shouldn't be more than that many, but we don't want to overflow the delayed job
        # handler field with the values.
        results.in_groups_of(100, false) do |addresses|
          Address.delay.update_kewill_addresses addresses
        end
      end

      render_ok
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