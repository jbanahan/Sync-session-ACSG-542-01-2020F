require 'open_chain/report/landed_cost_data_generator'

# Generates landed cost data and renders it to a string.
class LocalLandedCostsController
  include LocalControllerSupport

  def show id
   show_landed_cost_data OpenChain::Report::LandedCostDataGenerator.new.landed_cost_data_for_entry id
  end

  def show_landed_cost_data data
    render_view({landed_cost: data}, {layout: "layouts/standalone", template: "landed_costs/show"})
  end
end