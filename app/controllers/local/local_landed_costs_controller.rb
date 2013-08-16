require 'open_chain/report/landed_cost_data_generator'

# Generates landed cost data and renders it to a string.
class LocalLandedCostsController < LocalController

  def show id
    @landed_cost = OpenChain::Report::LandedCostDataGenerator.new.landed_cost_data_for_entry id

    render layout: "standalone", template: "landed_costs/show"
  end
end