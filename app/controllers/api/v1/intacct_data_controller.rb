require 'open_chain/sql_proxy_client'
require 'open_chain/custom_handler/intacct/intacct_invoice_details_parser'
require 'open_chain/custom_handler/intacct/intacct_client'

module Api; module V1; class IntacctDataController < SqlProxyPostbackController

  before_filter :require_admin

  def receive_alliance_invoice_details
    extract_results(params) do |p, context|
      OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser.delay.parse_query_results p.to_json
      render json: {"OK" => ""}
    end
  end

  def receive_check_result
    extract_results(params) do |p, context|
      OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser.delay.parse_check_result p.to_json
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

end; end; end