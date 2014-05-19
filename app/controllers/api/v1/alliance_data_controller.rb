require 'open_chain/alliance_parser'

module Api; module V1; class AllianceDataController < SqlProxyPostbackController

  def receive_alliance_entry_details 
    # Really all we're doing here is just delaying off the processing of the params being posted
    extract_results (params) do |results, context|
      OpenChain::AllianceParser.delay.process_alliance_query_details results.to_json, context.to_json
      render json: {"OK" => ""}
    end
  end

end; end; end