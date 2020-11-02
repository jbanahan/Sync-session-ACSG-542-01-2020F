module OpenChain; module ModelFieldDefinition; module EventSubscriptionDefinition
  def add_event_subscription_fields
    add_fields CoreModule::EVENT_SUBSCRIPTION, [
      [1, :evnts_event_type, :event_type, "Event type", {data_type: :string}],
      [2, :evnts_email, :email, "Email?", {data_type: :boolean}],
      [3, :evnts_system_message, :system_message, "System message?", {data_type: :boolean}]
    ]
  end
end; end; end