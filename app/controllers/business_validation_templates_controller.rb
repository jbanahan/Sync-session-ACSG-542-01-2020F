class BusinessValidationTemplatesController < ApplicationController

  def new
    admin_secure {
      @new_bvt = BusinessValidationTemplate.new
    }
  end

  def create
    admin_secure {
      @bvt = BusinessValidationTemplate.new(params[:business_validation_template])

      if @bvt.save
        redirect_to edit_business_validation_template_path(@bvt), notice: "Template successfully created."
      else
        render action: "new"
      end
    }
  end

  def edit
    admin_secure {
      @bvt = BusinessValidationTemplate.find(params[:id])
      @criteria = @bvt.search_criterions
      @rules = @bvt.business_validation_rules
      @new_criterion = SearchCriterion.new
      @new_rule = BusinessValidationRule.new
    }
  end

  def update
    admin_secure {
      @bvt = BusinessValidationTemplate.find(params[:id])

      if params[:search_criterions_only] == true
        @bvt.search_criterions = []
        params[:business_validation_template][:search_criterions].each do |search_criterion|
          add_search_criterion_to_template(@bvt, search_criterion)
        end unless params[:business_validation_template][:search_criterions].blank?
        render json: {ok: "ok"}

      else
        if @bvt.update_attributes(params[:business_validation_template])
          flash[:success] = "Template successfully saved."
          redirect_to @bvt
        else
          render 'edit'
        end

      end
    }
  end

  def index
    admin_secure {
      @bv_templates = BusinessValidationTemplate.all
    }
  end

  def show
    admin_secure {
      @bv_template = BusinessValidationTemplate.find params[:id]
    }
  end

  def destroy
    admin_secure{
      @bv_template = BusinessValidationTemplate.find params[:id]
      @bv_template.destroy

      redirect_to business_validation_templates_path
    }
  end

  def manage_criteria
    @no_action_bar = true
    @bvt = BusinessValidationTemplate.find(params[:id])
  end

  def edit_angular
    admin_secure do
      model_fields_list = make_model_fields_hashes
      business_template_hash = make_business_template_hash

      render json: {model_fields: model_fields_list, business_template: business_template_hash}
    end
  end

  private

  def add_search_criterion_to_template(template, criterion)
    criterion["model_field_uid"] = criterion.delete("uid")
    criterion.delete("datatype")
    criterion.delete("label")
    sc = SearchCriterion.new(criterion)
    template.search_criterions << sc
    template.save!
  end

  def make_business_template_hash
    bt = BusinessValidationTemplate.find(params[:id])
    bt_json = JSON.parse(bt.to_json(include: [:search_criterions =>{:only => [:value, :model_field_uid, :operator]}]))
    bt_json["business_validation_template"]["search_criterions"].each do |sc| 
      sc["datatype"] = ModelField.find_by_uid(sc["model_field_uid"]).data_type.to_s
      sc["label"] = ModelField.find_by_uid(sc["model_field_uid"]).label.to_s
      sc["uid"] = sc.delete("model_field_uid")
    end unless bt_json["business_validation_template"]["search_criterions"].blank?
    return bt_json
  end

  def make_model_fields_hashes
    @model_fields = ModelField.find_by_module_type(BusinessValidationTemplate.find(params[:id]).module_type.capitalize.to_sym)
    model_fields_list = []
    @model_fields.each do |model_field|
      model_fields_list << {
          :field_name => model_field.field_name.to_s, :uid => model_field.uid.to_s, 
          :label => model_field.label, :datatype => model_field.data_type.to_s
          }
    end
    return model_fields_list
  end

end
