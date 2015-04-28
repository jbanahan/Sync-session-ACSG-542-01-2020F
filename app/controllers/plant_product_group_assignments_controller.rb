require 'open_chain/workflow_processor'
class PlantProductGroupAssignmentsController < ApplicationController
  def show
    ppga = PlantProductGroupAssignment.find params[:id]
    action_secure(ppga.can_view?(current_user),ppga,{:verb=>"view",:module_name=>"plant product group assignment"}) {
      @ppga = ppga

      #enables state toggle buttons
      @state_button_path = 'plant_product_group_assignments'
      @state_button_object_id = @ppga.id
    }
  end

  def update
    ppga = PlantProductGroupAssignment.find params[:id]
    action_secure(ppga.can_edit?(current_user),ppga,{:verb=>"edit",:module_name=>"plant product group assignment"}) {
      succeed = lambda {|pl|
        OpenChain::WorkflowProcessor.async_process(ppga.plant.company)
        add_flash :notices, "Product Group assignment was updated successfully."
        redirect_to vendor_vendor_plant_plant_product_group_assignment_path(ppga.plant.company,ppga.plant,ppga)
      }
      failure = lambda {|pl,errors|
        errors_to_flash pl, :now=>true
        @ppga = ppga
        #enables state toggle buttons
        @state_button_path = 'plant_product_group_assignments'
        @state_button_object_id = @ppga.id
        render :action=>"show"
      }
      validate_and_save_module ppga, params[:plant_product_group_assignment], succeed, failure
    }
  end
end
