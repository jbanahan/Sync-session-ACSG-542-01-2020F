# You can extend this class primarily as a means for utilizing the full rails render pipeline
# outside of a http request.  For instance, to render a view page and store the page in a file.
# In general, you'll follow the exact same structure methods to render locally as you would
# from a standard controller.  The difference is that you'll have to manually call the controller method.
module LocalControllerSupport
  extend ActiveSupport::Concern

  def render_view view_assigns, render_opts
    av = ActionView::Base.new(ActionController::Base.view_paths, view_assigns)
    av.class_eval do
      # include any needed helpers (for the view)
      include ApplicationHelper
    end

    av.render render_opts
  end
end