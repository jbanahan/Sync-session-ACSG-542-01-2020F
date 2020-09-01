class ApiSessionsController < ApplicationController
  SEARCH_PARAMS = {
    'class_name' => {field: 'class_name', label: "Class"},
    'endpoint' => {field: 'server', label: "Endpoint"},
    'created_at' => {field: 'created_at', label: "Created At"},
    'updated_at' => {field: 'updated_at', label: "Sent At"}
  }.freeze

  def index
    sys_admin_secure do
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'class_name', 'created_at', 'd')
      # No field has been selected...ie it's the initial page load
      if params[:f1].blank?
        s = s.where("created_at > ?", Time.zone.now.beginning_of_day)
        @default_display = "By default, only API Sessions from today are displayed when no search fields are utilized."
      end

      @api_sessions = s.paginate(per_page: 40, page: params[:page])
      render layout: 'one_col'
    end
  end

  def show
    sys_admin_secure { @api_session = ApiSession.where(id: params[:id]).includes(:attachments).first }
  end

  private

  def secure
    ApiSession.find_can_view(current_user)
  end
end
