require 'open_chain/report/landed_cost_data_generator'

# Generates landed cost data and renders it to a string.
class LocalLandedCostsController < LocalController

  def show id
   show_landed_cost_data OpenChain::Report::LandedCostDataGenerator.new.landed_cost_data_for_entry id
  end

  def show_landed_cost_data data
    @landed_cost = data

    render layout: "standalone", template: "landed_costs/show"
  end
end