class RuntimeLogsController < ApplicationController

  SEARCH_PARAMS = {
    'identifier' => {field: 'identifier', label: 'Identifer'},
    'runtime_logable_type' => {field: 'runtime_logable_type', label: 'Type of log'},
    'created_at' => {field: 'created_at', label: "Created At"},
    'start' => {field: 'start', label: 'Start'},
    'end' => {field: 'end', label: "End"}
  }.freeze

  def set_page_title
    @page_title = 'Runtime Logs'
  end

  def index
    admin_secure do
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'runtime_logable_type', 'start', 'end')
      # No field has been selected...ie it's the initial page load
      if params[:f1].blank?
        s = s.where("created_at > ?", Time.zone.now.beginning_of_day)
        @default_display = "By default, only emails sent today are displayed when no search fields are utilized."
      end
      respond_to do |format|
          format.html do
              @runtime_logs = s.paginate(per_page: 40, page: params[:page])
              render layout: 'one_col'
          end
      end
    end
  end

  private

  def secure
    RuntimeLog.find_can_view(current_user)
  end
end
