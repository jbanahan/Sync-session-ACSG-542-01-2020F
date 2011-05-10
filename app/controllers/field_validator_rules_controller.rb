class FieldValidatorRulesController < ApplicationController

  def index
    admin_secure {
      @rules = FieldValidatorRule.all
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
