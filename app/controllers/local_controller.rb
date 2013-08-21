# You can extend this class primarily as a means for utilizing the full rails render pipeline
# outside of a http request.  For instance, to render a view page and store the page in a file.
# In general, you'll follow the exact same structure methods to render locally as you would
# from a standard controller.  The difference is that you'll have to manually call the controller method.
class LocalController < AbstractController::Base

  include AbstractController::Rendering
  include AbstractController::Layouts
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths
  include Rails.application.routes.url_helpers

  helper ApplicationHelper

  self.view_paths = "app/views"
  self.assets_dir = "app/public"

end