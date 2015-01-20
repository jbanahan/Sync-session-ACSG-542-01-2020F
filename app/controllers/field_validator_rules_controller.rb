class FieldValidatorRulesController < ApplicationController

  def validate
    mf_id = params[:mf_id]
    msgs = []
    rules = FieldValidatorRule.find_cached_by_model_field_uid mf_id
    v = params[:value]
    mf = ModelField.find_by_uid mf_id
    case mf.data_type
    when :date
      unless v.blank?
        v = Date.parse(v) rescue msgs << "#{v} is not a valid date format."
      end
    when :integer
      v = v.to_i
    when :decimal
      v = v.to_f
    when :datetime
      unless v.blank?
        v = Time.zone.parse(v) rescue msgs << "#{v} is not a valid date time format."
      end
    end
    rules.each do |r|
      msgs += r.validate_input v
    end
    render :json=>msgs
  end

  def index
    admin_secure {
      @rules = FieldValidatorRule.all.sort do |a, b| 
        mod_a, mod_b = CoreModule.find_by_class_name(a.module_type).label, CoreModule.find_by_class_name(b.module_type).label
        val = mod_a <=> mod_b
        if val == 0
          val = FieldLabel.default_value(a.model_field_uid) <=> FieldLabel.default_value(b.model_field_uid)
        end
        val
      end
    }
  end

  def new 
    admin_secure {
      model_field_id = params[:mf_id]
      if model_field_id.blank?
        error_redirect "mf_id parameter must be set to create a new rule" 
        return
      end
      if ModelField.find_by_uid(model_field_id).blank?
        error_redirect "ModelField with id #{model_field_id} not found."
        return
      end
      rule = FieldValidatorRule.where(:model_field_uid=>model_field_id).first
      rule = FieldValidatorRule.create(:model_field_uid=>model_field_id) if rule.nil?
      redirect_to edit_field_validator_rule_path rule
    }
  end 

  def edit
    admin_secure {
      @rule = FieldValidatorRule.find params[:id]
    }
  end

  def show
    admin_secure {
      @rule = FieldValidatorRule.find params[:id]
      render 'edit'
    }
    
  end

  def update
    admin_secure {
      @rule = FieldValidatorRule.find params[:id]
      if @rule.update_attributes(params[:field_validator_rule])
        add_flash :notices, "Rule was updated successfully."
        redirect_to field_validator_rules_path 
      else
        errors_to_flash @rule, :now=>true
        render 'edit'
      end
    }
  end

  def destroy
    admin_secure {
      rule = FieldValidatorRule.find params[:id]
      if rule.destroy
        add_flash :notices, "Rule was deleted successfully."
        redirect_to field_validator_rules_path
      else
        @rule = rule
        errors_to_flash rule, :now=>true
        render 'edit'
      end
    }
  end
end
