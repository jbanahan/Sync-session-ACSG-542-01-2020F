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
      if @bvt.update_attributes(params[:business_validation_template])
        flash[:success] = "Template successfully saved."
        redirect_to @bvt
      else
        render 'edit'
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

end
