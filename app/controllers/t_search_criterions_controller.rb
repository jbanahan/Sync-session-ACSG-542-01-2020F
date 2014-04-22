class TSearchCriterionsController < ApplicationController
  def create
    admin_secure do
      @sc = SearchCriterion.new(params[:search_criterion])
      @sc.business_validation_template = BusinessValidationTemplate.find(params[:business_validation_template_id])

      if @sc.save!
        redirect_to edit_business_validation_template_path(@sc.business_validation_template)
      else
        error_redirect "There was an error while attempting to add your new criterion to this template."
      end
    end
  end

  def destroy
    admin_secure do
      @sc = SearchCriterion.find(params[:id])
      @bvt = @sc.business_validation_template
      @sc.destroy
      redirect_to edit_business_validation_template_path(@bvt)
    end
  end
end