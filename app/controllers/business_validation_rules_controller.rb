class BusinessValidationRulesController < ApplicationController

  def create
    admin_secure do
      @bvr = BusinessValidationRule.new(params[:business_validation_rule])
      @bvt = BusinessValidationTemplate.find(params[:business_validation_template_id])
      @bvr.business_validation_template = @bvt # this will be unnecessary if b_v_t goes in attr_accessible

      begin
        JSON.parse(params[:business_validation_rule][:rule_attributes_json]) unless params[:business_validation_rule][:rule_attributes_json].blank? 
        valid_json = true
      rescue
        valid_json = false
      end

      if valid_json
        if @bvr.save!
          redirect_to edit_business_validation_template_path(@bvt)
        else
          error_redirect "The rule could not be created."
        end
      else
        error_redirect "Could not save due to invalid JSON. For reference, your attempted JSON was: #{params[:business_validation_rule][:rule_attributes_json]}"
      end
    end
  end

  def edit #used for adding a criterion to a rule
    admin_secure{
      @new_criterion = SearchCriterion.new
      @bvr = BusinessValidationRule.find(params[:id])
    }
  end

  def update
    admin_secure{
      @bvr = BusinessValidationRule.find(params[:id])
      if @bvr.update_attributes(params[:business_validation_rule])
        @bvr.save!
        flash[:success] = "Criterion successfully added to rule."
        redirect_to @bvr.business_validation_template
      else
        error_redirect "Criterion could not be added to rule."
      end
    }
  end

  def destroy
    admin_secure do 
      @bvr = BusinessValidationRule.find(params[:id])
      @bvt = @bvr.business_validation_template
      @bvr.destroy
      redirect_to edit_business_validation_template_path(@bvt)
    end
  end
end