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
    @no_action_bar = true
    admin_secure{
      @new_criterion = SearchCriterion.new
      @bvr = BusinessValidationRule.find(params[:id])
    }
  end

  def update
    admin_secure{
      @bvr = BusinessValidationRule.find(params[:id])
      if params[:search_criterions_only] == true
        @bvr.search_criterions = []
        params[:business_validation_rule][:search_criterions].each do |search_criterion|
          add_search_criterion_to_rule(@bvr, search_criterion)
        end unless params[:business_validation_rule][:search_criterions].blank?
        render json: {ok: "ok"}
      else
        if @bvr.update_attributes(params[:business_validation_rule])
          @bvr.save!
          flash[:success] = "Criterion successfully added to rule."
          redirect_to @bvr.business_validation_template
        else
          error_redirect "Criterion could not be added to rule."
        end
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

  def edit_angular
    admin_secure do

      model_fields_list = make_model_fields_hashes
      business_rule_hash = make_business_rule_hash

      render json: {model_fields: model_fields_list, business_validation_rule: business_rule_hash[:business_validation_rule]}
    end
  end

  private

  def add_search_criterion_to_rule(rule, criterion)
    criterion["model_field_uid"] = criterion.delete("mfid")
    criterion.delete("datatype")
    criterion.delete("label")
    sc = SearchCriterion.new(criterion)
    rule.search_criterions << sc
    rule.save!
  end

  def make_business_rule_hash
    br = BusinessValidationRule.find(params[:id])
    # Hand created to avoid extraneous attributes and including the concrete validation rule's subclass name as the root
    # attribute name instead of 'business_validation_rule'
    br_json = {business_validation_rule: 
      {
        business_validation_template_id: br.business_validation_template_id,
        description: br.description,
        fail_state: br.fail_state,
        id: br.id,
        name: br.name,
        rule_attributes_json: br.rule_attributes_json
      }
    }
    
    br_json[:business_validation_rule][:search_criterions] = br.search_criterions.collect {|sc| sc.json current_user}
    br_json
  end

  def make_model_fields_hashes
    @model_fields = ModelField.find_by_module_type(BusinessValidationRule.find(params[:id]).business_validation_template.module_type.capitalize.to_sym)
    model_fields_list = []
    @model_fields.each do |model_field|
      model_fields_list << {
          :field_name => model_field.field_name.to_s, :mfid => model_field.uid.to_s, 
          :label => model_field.label, :datatype => model_field.data_type.to_s
          }
    end
    model_fields_list
  end

end