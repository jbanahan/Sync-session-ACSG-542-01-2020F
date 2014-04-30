require 'open_chain/sql_proxy_client'
require 'open_chain/custom_handler/intacct/intacct_invoice_details_parser'
require 'open_chain/custom_handler/intacct/intacct_client'

module Api; module V1; class IntacctDataController < ApiController

  before_filter :require_admin

  def receive_alliance_invoice_numbers
    # This is the callback action handling the query returning invoice #'s cut in the last X# days. 
    extract_results(params) do |p|
      # Put this in a thread since we're likely dealing with lookups for hundreds (or more) invoices at a time...all that matters
      # to the client is that the numbers were successfully pushed to this action
      run_in_thread do 
        p.each do |row|
          # We're only going to request invoice details for file/suffixes we haven't already got data for or those where the data is delinquent
          # (we'll say over 30 minutes ago as a starting point)      
          suffix = row[:s].blank? ? nil : row[:s].strip

          export = IntacctAllianceExport.where(file_number: row[:f], suffix: suffix).where("(data_received_date IS NOT NULL OR data_requested_date > ?)", Time.zone.now - 30.minutes).first

          unless export
            OpenChain::SqlProxyClient.delay.request_alliance_invoice_details row[:f], suffix
          end
        end
      end
      render json: {"OK" => ""}
    end

  end

  def receive_alliance_invoice_details
    extract_results(params) do |p|
      OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser.delay.parse_query_results p.to_json
      render json: {"OK" => ""}
    end
  end

  private 

    def extract_results params, null_response = {"OK" => ""}
      # Params may be nil in cases where a query didn't return any results (rails munges JSON like {'results':[]} into {'results':nil}).
      # So don't return an error if results is there but it's null, just don't yield.
      if (params.include?("results") && params[:results].nil?) || (params[:results] && params[:results].respond_to?(:each))
        if params[:results]
          yield params[:results]
        else
          render json: null_response
        end
      else
        render_error "Bad Request", :bad_request
      end
    end

    def require_admin
      render_forbidden unless User.current.admin?
    end

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