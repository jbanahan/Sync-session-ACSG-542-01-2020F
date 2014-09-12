class EventSubscription < ActiveRecord::Base
  belongs_to :user, inverse_of: :event_subscriptions, touch: true

  validates :user, presence: true
  validates :event_type, presence: true

  def self.subscriptions_for_event event_type, subscription_type, object_id
    all_subs = EventSubscription.where(event_type:event_type).where(subscription_type=>true).includes(:user)
    obj = object_for_event_type(event_type,object_id)
    return [] unless obj
    matches = all_subs.collect {|es| obj.can_view?(es.user) ? es : nil}.compact
  end

  private
  def self.object_for_event_type event_type, object_id
    case event_type
    when /_COMMENT_CREATE$/
      Comment.find(object_id).commentable
    when 'ORDER_CLOSE' || 'ORDER_REOPEN'
      Order.find(object_id)
    end
  end
end
