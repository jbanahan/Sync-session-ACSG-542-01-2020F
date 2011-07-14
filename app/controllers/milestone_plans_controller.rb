class MilestonePlansController < ApplicationController

  def index
    respond_to do |format|
      format.json { render :json => MilestonePlan.all}
      format.html {}
    end
  end

  def edit
    admin_secure {
      @available_fields = CoreModule.grouped_options({:core_modules=>[CoreModule::ORDER,CoreModule::ORDER_LINE,CoreModule::SHIPMENT,CoreModule::SHIPMENT_LINE,CoreModule::SALE,CoreModule::SALE_LINE,CoreModule::DELIVERY,CoreModule::DELIVERY_LINE],
          :filter=>lambda {|f| [:date,:datetime].include?(f.data_type)}})
      @milestone_plan = MilestonePlan.find params[:id]
    }
  end

  def new
    admin_secure {
      @available_fields = CoreModule.grouped_options({:core_modules=>[CoreModule::ORDER,CoreModule::ORDER_LINE,CoreModule::SHIPMENT,CoreModule::SHIPMENT_LINE,CoreModule::SALE,CoreModule::SALE_LINE,CoreModule::DELIVERY,CoreModule::DELIVERY_LINE],
          :filter=>lambda {|f| [:date,:datetime].include?(f.data_type)}})
      @milestone_plan = MilestonePlan.new
    }
  end
  def create 
    admin_secure {
      MilestonePlan.transaction do
        @milestone_plan = MilestonePlan.create(params[:milestone_plan])
        build_definitions @milestone_plan
        @milestone_plan.save
        if @milestone_plan.errors.blank?
          add_flash :notices, "Milestone plan created successfully."
          redirect_to edit_milestone_plan_path(@milestone_plan)
        else
          errors_to_flash @milestone_plan
          render :action => 'new'
        end
      end
    }
  end 

  def update
    admin_secure {
      MilestonePlan.transaction do 
        mp = MilestonePlan.find params[:id]
        mp.update_attributes params[:milestone_plan]
        add_flash :notices, "Plan updated successfully."
      end
      redirect_to milestone_plans_path
    }
  end

  private
  def build_definitions mp
    rows = params[:milestone_definition_rows].clone
    bad_rows = false #break the loop if all of the rows fail in the hash on any single pass
    while !rows.blank? && !bad_rows
      bad_rows = true
      rows.each do |k,r|
        bad_rows = false if process_row mp, r, rows, k
      end
    end
  end
  def process_row milestone_plan, row, rows_hash, row_key
    previous_def = nil #milestone definition object 
    existing_def = nil #existing milestone definition object already set to this model_field_uid
    milestone_plan.milestone_definitions.each do |md|
      previous_def = md if row['previous_model_field_uid']==md.model_field_uid
      existing_def = md if row['model_field_uid']==md.model_field_uid
    end
    return nil unless previous_def #if we didn't find the previous model field then it hasn't been built yet, so don't do anything
    attribute_hash = {:model_field_uid=>row['model_field_uid'],:previous_milestone_definition_id=>previous_def.id,:days_after_previous=>row[:days_after_previous],:final_milestone=>!row['final_milestone'].blank?}
    definition = nil
    if existing_def
      existing_def.update_attributes(attribute_hash)
      definition = existing_def
    else
      definition = milestone_plan.milestone_definitions.create(attribute_hash)
    end
    rows_hash.delete row_key
    return definition
  end
end
