module Api; module V1; module Admin; class AdminApiController < Api::V1::ApiController
  around_filter :admin_only

  def admin_only
    raise StatusableError.new("Access denied.", :unauthorized) unless current_user.admin?
    yield
  end
end; end; end; end