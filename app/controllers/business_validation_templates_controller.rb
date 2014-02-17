class BusinessValidationTemplatesController < ApplicationController
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
end
