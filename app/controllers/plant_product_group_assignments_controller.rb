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
end
