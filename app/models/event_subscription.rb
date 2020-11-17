# == Schema Information
#
# Table name: event_subscriptions
#
#  created_at     :datetime         not null
#  email          :boolean
#  event_type     :string(255)
#  id             :integer          not null, primary key
#  system_message :boolean
#  updated_at     :datetime         not null
#  user_id        :integer
#
# Indexes
#
#  index_event_subscriptions_on_user_id  (user_id)
#

class EventSubscription < ActiveRecord::Base
  belongs_to :user, inverse_of: :event_subscriptions, touch: true

  validates :user, presence: true
  validates :event_type, presence: true

  def self.subscriptions_for_event event_type, subscription_type, object_id: nil, object: nil
    if object_id.present?
      obj = object_for_event_type(event_type, object_id)
    else
      obj = object
    end

    return [] unless obj
    all_subs = EventSubscription.where(event_type: event_subscription_type(event_type, obj)).where(subscription_type => true).includes(:user)
    all_subs.collect {|es| (es.user.active? && obj.can_view?(es.user)) ? es : nil}.compact
  end

  def self.object_for_event_type event_type, object_id
    # The order of these when statements is relevant, don't shift them around
    # Make sure to either raise a RecordNotFound exception or return nil if the object
    # can't be found, anything else can cause an error, which may cause issues in the
    # actual event queue client being able to finish with the event message - and the
    # message getting stuck in the queue

    case event_type
    when /COMMENT_CREATE$/
      Comment.find(object_id).commentable
    else
      core_module_name = event_type.split('_').first
      cm = CoreModule.by_class_name(core_module_name, true) # case insensitive
      raise "CoreModule not found for #{core_module_name}" if cm.nil?
      cm.find object_id
    end
  rescue ActiveRecord::RecordNotFound
    # Don't care...this can happen if a comment or base object is removed prior to all the subscribed
    # events getting sent out through the queue.  So just return nil.
    nil
  end

  class << self

    private

      def event_subscription_type event_type, object
        case event_type
        when 'COMMENT_CREATE'
          "#{object.class.name.upcase}_COMMENT_CREATE"
        else
          event_type
        end
      end
  end

end
