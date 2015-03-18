class VendorProductGroupAssignmentsController < ApplicationController
  around_filter :view_secure
  def show
    @state_button_path = 'vendor_product_group_assignments'
    @state_button_object_id = @vpga.id
  end

  def view_secure
    @vpga = VendorProductGroupAssignment.find params[:id]
    action_secure(@vpga.can_view?(current_user), @vpga, {:verb => "view", :lock_check => true, :module_name=>"vendor product group assignment"}) do
      yield
    end
  end
end
