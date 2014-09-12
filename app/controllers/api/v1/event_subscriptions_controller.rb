module Api; module V1; class EventSubscriptionsController < Api::V1::ApiController

  def index
    render_subscriptions find_user
  end

  def create
    u = find_user
    raise StatusableError.new("Permission denied.",401) unless u.can_edit?(current_user)
    User.transaction do
      u.event_subscriptions.destroy_all
      params[:event_subscriptions].each do |es|
        u.event_subscriptions.build(
          event_type:es['event_type'],
          email:es['email']
          )
      end
      u.save!
    end
    render_subscriptions u
  end

  private
  def render_subscriptions user
    r = []
    user.event_subscriptions.each do |s|
      r << {user_id:s.user_id,event_type:s.event_type,email:s.email?}
    end
    render json: {event_subscriptions:r}
  end

  def find_user
    u = User.find params[:user_id]
    raise StatusableError.new("Not found.",404) unless u.can_view?(current_user)
    u
  end
end; end; end