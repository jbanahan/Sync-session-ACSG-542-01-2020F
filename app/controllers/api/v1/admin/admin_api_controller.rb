module Api; module V1; module Admin; class AdminApiController < Api::V1::ApiController
  before_action :require_admin

end; end; end; end