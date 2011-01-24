class MilestonePlansController < ApplicationController
  def index
    action_secure(current_user.edit_milestone_plans?, nil, {:verb => "work with", :lock_check => false, :module_name=>"milestone plan"}) {
      @plans = MilestonePlan.ranked
    }
  end
  
  def new
    p = MilestonePlan.new
    action_secure(current_user.edit_milestone_plans?,p,{:verb => "create",:module_name=>"milestone plan",:lock_check=>false}) {
      @plan = p

      respond_to do |format|
          format.html # new.html.erb
          format.xml  { render :xml => @plan }
      end
    }
  end
  
  def show
    p = MilestonePlan.find(params[:id])
    action_secure(current_user.edit_milestone_plans?,p,{:verb => "view",:module_name=>"milestone plan"}) {
      @plan = p
    }
  end
  
  def edit
    p = MilestonePlan.find(params[:id])
    action_secure(current_user.edit_milestone_plans?,p,{:verb => "edit",:module_name=>"milestone plan"}) {
      @plan = p
    }
  end
  
  def create
    p = MilestonePlan.new(params[:milestone_plan])
      action_secure(current_user.edit_milestone_plans?,p,{:verb => "create",:module_name=>"milestone plan"}) {
        @plan = p
        respond_to do |format|
            if @plan.save
                add_flash :notices, "Milestone plan created successfully."
                format.html { redirect_to(@plan)}
                format.xml  { render :xml => @plan, :status => :created, :location => @plan }
            else
                errors_to_flash @plan, :now => true
                format.html { render :action => "new" }
                format.xml  { render :xml => @plan.errors, :status => :unprocessable_entity }
            end
        end
      } 
  end
  
  def update
    p = MilestonePlan.find(params[:id])
    action_secure(current_user.edit_milestone_plans?,p,{:verb => "edit",:module_name=>"milestone plan"}) {
      @plan = p
        respond_to do |format|
            if @plan.update_attributes(params[:milestone_plan])
                add_flash :notices, "Milestone plan updated successfully."
                format.html { redirect_to(@plan) }
                format.xml  { head :ok }
            else
                errors_to_flash @plan
                format.html { render :action => "edit" }
                format.xml  { render :xml => @plan.errors, :status => :unprocessable_entity }
            end
        end
    }
  end
  
  def destroy
    p = MilestonePlan.find(params[:id])
    action_secure(current_user.edit_milestone_plans?,p,{:verb => "delete",:module_name=>"milestone plan"}) {
      @plan = p
      add_flash :notices, "Milestone plan deleted." if @plan.destroy
      errors_to_flash @plan

      respond_to do |format|
          format.html { redirect_to(milestone_plans_url) }
          format.xml  { head :ok }
      end
    }
  end
  
  def test_criteria
    p = MilestonePlan.find(params[:id])
    action_secure(current_user.edit_milestone_plans?,p,{:verb => "test",:module_name=>"milestone plan"}) {
      p_sets = p.find_matching_piece_sets.order("piece_sets.updated_at DESC").limit(10).to_a
      respond_to do |format|
        format.json { render :json => p_sets.to_json(:only => [:id], :include => 
            {
              :product => {:only => [:name]}, 
              :order_line => {:only => [:line_number], :include => {:order => {:only => [:order_number]}}},
              :shipment => {:only => [:reference]},
              :sales_order_line => {:only => [:line_number], :include => {:sales_order => {:only => [:order_number]}}},
              :delivery => {:only => [:reference]}
            })
        }
      end
    }
  end
end