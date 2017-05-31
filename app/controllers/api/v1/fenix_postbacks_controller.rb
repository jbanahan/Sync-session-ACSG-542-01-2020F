require 'open_chain/fenix_parser'

module Api; module V1; class FenixPostbacksController < Api::V1::SqlProxyPostbacksController
  
  def receive_lvs_results
    extract_results(params) do |results|
      OpenChain::FenixParser.delay.parse_lvs_query_results results.to_json
      render json: {"OK" => ""}
    end
  end

end; end; end;