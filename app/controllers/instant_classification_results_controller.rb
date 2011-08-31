class InstantClassificationResultsController < ApplicationController
  def show
    admin_secure {
      @icr = InstantClassificationResult.find params[:id]
      @paged_results = @icr.instant_classification_result_records.paginate(:per_page=>25, :page => params[:page])
    }
  end
end
