class InstantClassificationResultsController < ApplicationController
  def show
    action_secure(current_user.edit_classifications?,Product.new,{:verb=>"view",:module_name=>"instant classification result",:lock_check=>false}) {
      @icr = InstantClassificationResult.find params[:id]
      @paged_results = @icr.instant_classification_result_records.paginate(:per_page=>25, :page => params[:page])
    }
  end
  def index
    action_secure(current_user.edit_classifications?,Product.new,{:verb=>"view",:module_name=>"instant classification result",:lock_check=>false}) {
      @results = current_user.instant_classification_results.order("created_at DESC").paginate(:per_page=>20,:page=>params[:page])
    }
  end
end
