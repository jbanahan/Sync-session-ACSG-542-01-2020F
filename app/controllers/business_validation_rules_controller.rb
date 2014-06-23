class BusinessValidationRulesController < ApplicationController

  def create
    admin_secure do
      @bvr = BusinessValidationRule.new(params[:business_validation_rule])
      @bvt = BusinessValidationTemplate.find(params[:business_validation_template_id])
      @bvr.business_validation_template = @bvt # this will be unnecessary if b_v_t goes in attr_accessible

      begin
        JSON.parse(params[:business_validation_rule][:rule_attributes_json])
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

      render json: {model_fields: model_fields_list, business_rule: business_rule_hash}
    end
  end

  private

  def add_search_criterion_to_rule(rule, criterion)
    criterion["model_field_uid"] = criterion.delete("uid")
    criterion.delete("datatype")
    criterion.delete("label")
    sc = SearchCriterion.new(criterion)
    rule.search_criterions << sc
    rule.save!
  end

  def make_business_rule_hash
    br = BusinessValidationRule.find(params[:id])
    br_json = JSON.parse(br.to_json(include: [:search_criterions =>{:only => [:value, :model_field_uid, :operator]}]))

    #remove the subclass key unless it somehow has no subclass (that should only happen in testing)
    br_json = br_json[br_json.keys.first] unless br_json.keys.first == "business_validation_rule"

    br_json["search_criterions"].each do |sc| 
      sc["datatype"] = ModelField.find_by_uid(sc["model_field_uid"]).data_type.to_s
      sc["label"] = ModelField.find_by_uid(sc["model_field_uid"]).label.to_s
      sc["uid"] = sc.delete("model_field_uid")
    end unless br_json["search_criterions"].blank?
    br_json
  end

  def make_model_fields_hashes
    @model_fields = ModelField.find_by_module_type(BusinessValidationRule.find(params[:id]).business_validation_template.module_type.capitalize.to_sym)
    model_fields_list = []
    @model_fields.each do |model_field|
      model_fields_list << {
          :field_name => model_field.field_name.to_s, :uid => model_field.uid.to_s, 
          :label => model_field.label, :datatype => model_field.data_type.to_s
          }
    end
    model_fields_list
  end

end