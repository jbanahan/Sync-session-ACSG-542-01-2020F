require 'open_chain/workflow_processor'
class VendorPlantsController < ApplicationController
  around_filter :view_permission_filter, only: [:show,:unassigned_product_groups]
  around_filter :edit_permission_filter, only: [:edit, :assign_product_group]
  def show
    @vendor = @plant.company

    #enables state toggle buttons
    @state_button_path = 'plants'
    @state_button_object_id = @plant.id
  end

  def edit
    @vendor = @plant.company
  end

  def update
    plant = Plant.find(params[:id])
    action_secure(plant.can_edit?(current_user),plant,{:module_name=>"plant",:verb=>'edit'}) {
      succeed = lambda {|pl|
        OpenChain::WorkflowProcessor.async_process pl.company
        add_flash :notices, "Plant was updated successfully."
        redirect_to vendor_vendor_plant_path(pl.company,pl)
      }
      failure = lambda {|pl,errors|
        errors_to_flash pl, :now=>true
        @plant = pl
        @vendor = @plant.company
        render :action=>"edit"
      }
      validate_and_save_module plant, params[:plant], succeed, failure
    }
  end

  def create
    vendor = Company.find(params[:vendor_id])
    action_secure(vendor.can_edit?(current_user),vendor,{:module_name=>'vendor',:verb=>'create plant'}) {
      succeed = lambda {|pl|
        OpenChain::WorkflowProcessor.async_process pl.company
        add_flash :notices, 'Plant was created successfully.'
        redirect_to edit_vendor_vendor_plant_path(pl.company,pl)
      }
      failure = lambda {|pl,errors|
        errors_to_flash pl
        redirect_to vendor_path(pl.vendor)
      }
      validate_and_save_module vendor.plants.build, params[:plant], succeed, failure
    }
  end

  def unassigned_product_groups
    h = {product_groups:[]}
    @plant.unassigned_product_groups.each do |pg|
      h[:product_groups] << {id:pg.id,name:pg.name}
    end
    render json: h
  end

  def assign_product_group
    pg = ProductGroup.find(params[:product_group_id])

    error_redirect 'ProductGroup already assigned.' unless @plant.plant_product_group_assignments.where(product_group_id:pg.id).empty?

    @plant.product_groups << pg

    OpenChain::WorkflowProcessor.async_process @plant.company
    
    render json: {'ok'=>'ok'}
  end

  def view_permission_filter
    plant = Plant.find params[:id]
    action_secure(plant.can_view?(current_user),plant,{:verb=>"view",:module_name=>"plant"}) {
      @plant = plant
      yield
    }
  end
  private :view_permission_filter

  def edit_permission_filter
    plant = Plant.find params[:id]
    action_secure(plant.can_edit?(current_user),plant,{:verb=>"edit",:module_name=>"plant"}) {
      @plant = plant
      yield
    }
  end
  private :edit_permission_filter
end
