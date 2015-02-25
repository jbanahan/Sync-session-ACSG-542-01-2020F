class EventSubscription < ActiveRecord::Base
  belongs_to :user, inverse_of: :event_subscriptions, touch: true

  validates :user, presence: true
  validates :event_type, presence: true

  def self.subscriptions_for_event event_type, subscription_type, object_id
    obj = object_for_event_type(event_type,object_id)
    return [] unless obj
    all_subs = EventSubscription.where(event_type:event_subscription_type(event_type,obj)).where(subscription_type=>true).includes(:user)
    all_subs.collect {|es| obj.can_view?(es.user) ? es : nil}.compact
  end

  private
  def self.event_subscription_type event_type, object
    case event_type
    when 'COMMENT_CREATE'
      return "#{object.class.name.upcase}_COMMENT_CREATE"
    else
      return event_type
    end
  end
  def self.object_for_event_type event_type, object_id
    # The order of these when statements is relevant, don't shift them around
    case event_type
    when /COMMENT_CREATE$/
      return Comment.find(object_id).commentable
    else
      core_module_name = event_type.split('_').first
      cm = CoreModule.find_by_class_name(core_module_name,true) #case insensitive
      raise "CoreModule not found for #{core_module_name}" if cm.nil?
      cm.find object_id
    end
  end
end
