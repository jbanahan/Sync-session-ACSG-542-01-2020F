module Api; module V1; module SnsApiControllerSupport
  extend ActiveSupport::Concern

  included do
    around_filter :set_integration_user
  end
  
  def set_integration_user
    pre_set_user_settings User.integration
    begin
      yield
    ensure
      post_set_user_settings
    end
  end

  module ClassMethods
    def skip_filters for_actions
      # SNS doesn't give you an option to include extra headers, so everything to do with the authtoken and setting users from that needs
      # to be skipped and replaced (see above)

      # The heroic-sns middelware handles request validation and making sure the requests are valid SNS notification requests.  As such,
      # we shouldn't have to worry about protecting actions that utilize SNS.
      skip_before_filter :require_admin, only: for_actions
      skip_around_filter :set_user_settings, only: for_actions
      skip_around_filter :validate_authtoken, only: for_actions

      # No Accept header is sent by SNS Posts, so we have to skip this filter too
      skip_before_filter :validate_format, only: for_actions
    end
  end

end; end; end;