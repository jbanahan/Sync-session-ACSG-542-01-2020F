module Api; module V1; module Admin; class EventSubscriptionsController < Api::V1::Admin::AdminApiController
  #/api/v1/admin/event_subscriptions/:event_type/:object_id/:subscription_type
  #/api/v1/admin/event_subscriptions/ORDER_CLOSE/17/email
  def show_by_event_type_object_id_and_subscription_type
    subs = EventSubscription.subscriptions_for_event params[:event_type], params[:subscription_type], params[:object_id]
    users = Set.new
    subs.each {|s| users << s.user}
    render json:{event_subscription_users:users.collect {|u| {id:u.id,email:u.email,first_name:u.first_name,last_name:u.last_name,full_name:u.full_name}}}
  end
end; end; end; end