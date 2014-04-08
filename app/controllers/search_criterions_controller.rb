class SearchCriterionsController < ApplicationController

  def create
    admin_secure do 
      @sc = SearchCriterion.new(params[:search_criterion])

      if @sc.save!
        if @bvt = @sc.business_validation_template
          redirect_to edit_business_validation_template_path(@bvt)
        else
          @bvt = @sc.business_validation_rule.business_validation_template
          redirect_to business_validation_template_path(@bvt)
        end
      else
        error_redirect "The search criterion could not be saved."
      end
    end
  end

  def destroy
    admin_secure do
      @sc = SearchCriterion.find(params[:id])
      if !@sc.business_validation_template.nil?
        @bvt = @sc.business_validation_template
        redirect_to edit_business_validation_template_path(@bvt)
      else
        @bvt = @sc.business_validation_rule.business_validation_template
        redirect_to business_validation_template_path(@bvt)
      end
      @sc.destroy
    end
  end

end
