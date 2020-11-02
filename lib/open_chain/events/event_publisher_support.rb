module OpenChain; module Events; module EventPublisherSupport
  extend ActiveSupport::Concern

  MessageType ||= Struct.new(:type, :link_lambda, :short_message_lambda, :long_message_lambda) do

    def link obj
      link_lambda.call(obj)
    end

    def short_message obj
      short_message_lambda.call(obj)
    end

    def long_message obj
      long_message_lambda.call(obj)
    end

    def to_h obj
      # TODO - Move host and API Token to sqs publisher
      {
        event_type: type,
        klass: obj.class.name,
        id: obj.id,
        link: self.link(obj),
        short_message: self.short_message(obj),
        long_message: self.long_message(obj)
      }
    end
  end

  MESSAGE_PROCESSORS ||= {
    comment_create: MessageType.new(
      'COMMENT_CREATE',
      ->(obj) { "#{MasterSetup.get.request_url_base}/comments/#{obj.id}"},
      ->(obj) { # rubocop:disable Style/Lambda
        cm = CoreModule.by_object(obj.commentable)
        "Comment: #{cm.label} #{cm.logical_key(obj.commentable)} from #{obj.user.full_name}: #{obj.subject}"
      },
      ->(obj) { "Comment Added:\n\n#{obj.body}" }
    ),
    order_close: MessageType.new(
      'ORDER_CLOSE',
      ->(obj) { "#{MasterSetup.get.request_url_base}/orders/#{obj.id}"},
      ->(obj) { "Order #{obj.display_order_number} closed."},
      ->(obj) { "Order #{obj.display_order_number} closed by #{obj.closed_by.full_name} at #{obj.closed_at}."}
    ),
    order_reopen: MessageType.new(
      'ORDER_REOPEN',
      ->(obj) { "#{MasterSetup.get.request_url_base}/orders/#{obj.id}"},
      ->(obj) { "Order #{obj.display_order_number} reopened."},
      ->(obj) { "Order #{obj.display_order_number} reopened."}
    ),
    order_accept: MessageType.new(
      'ORDER_ACCEPT',
      ->(obj) { "#{MasterSetup.get.request_url_base}/orders/#{obj.id}"},
      ->(obj) { "Order #{obj.display_order_number} accepted."},
      ->(obj) { "Order #{obj.display_order_number} accepted."}
    ),
    order_unaccept: MessageType.new(
      'ORDER_UNACCEPT',
      ->(obj) { "#{MasterSetup.get.request_url_base}/orders/#{obj.id}"},
      ->(obj) { "Order #{obj.display_order_number} unaccepted."},
      ->(obj) { "Order #{obj.display_order_number} unaccepted."}
    ),
    order_create: MessageType.new(
      'ORDER_CREATE',
      ->(obj) { "#{MasterSetup.get.request_url_base}/orders/#{obj.id}"},
      ->(obj) { "Order #{obj.display_order_number} created."},
      ->(obj) { "Order #{obj.display_order_number} created."}
    ),
    order_update: MessageType.new(
      'ORDER_UPDATE',
      ->(obj) { "#{MasterSetup.get.request_url_base}/orders/#{obj.id}"},
      ->(obj) { "Order #{obj.display_order_number} updated."},
      ->(obj) { "Order #{obj.display_order_number} updated."}
    ),
    shipment_booking_request: MessageType.new(
      'SHIPMENT_BOOK_REQ',
      ->(obj) { "#{MasterSetup.get.request_url_base}/shipments/#{obj.id}"},
      ->(obj) { "Shipment #{obj.reference} booking requested."},
      ->(obj) { "Shipment #{obj.reference} booking requested."}
    ),
    shipment_booking_confirm: MessageType.new(
      'SHIPMENT_BOOK_CONFIRM',
      ->(obj) { "#{MasterSetup.get.request_url_base}/shipments/#{obj.id}"},
      ->(obj) { "Shipment #{obj.reference} booking confirmed."},
      ->(obj) { "Shipment #{obj.reference} booking confirmed."}
    ),
    shipment_booking_approve: MessageType.new(
      'SHIPMENT_BOOK_APPROVE',
      ->(obj) { "#{MasterSetup.get.request_url_base}/shipments/#{obj.id}"},
      ->(obj) { "Shipment #{obj.reference} booking approved."},
      ->(obj) { "Shipment #{obj.reference} booking approved."}
    ),
    shipment_cancel: MessageType.new(
      'SHIPMENT_CANCEL',
      ->(obj) { "#{MasterSetup.get.request_url_base}/shipments/#{obj.id}"},
      ->(obj) { "Shipment #{obj.reference} has been canceled."},
      ->(obj) { "Shipment #{obj.reference} has been canceled."}
    ),
    shipment_cancel_request: MessageType.new(
      'SHIPMENT_REQUEST_CANCEL',
      ->(obj) { "#{MasterSetup.get.request_url_base}/shipments/#{obj.id}"},
      ->(obj) { "Shipment #{obj.reference} cancellation requested."},
      ->(obj) { "Shipment #{obj.reference} cancellation requested."}
    ),
    shipment_instructions_send: MessageType.new(
      'SHIPMENT_INSTRUCTIONS_SEND',
      ->(obj) { "#{MasterSetup.get.request_url_base}/shipments/#{obj.id}"},
      ->(obj) { "Shipment #{obj.reference} instructions sent."},
      ->(obj) { "Shipment #{obj.reference} instructions sent."}
    )
  }.freeze

  class_methods do

    def event_descriptor message_type, object
      processor = MESSAGE_PROCESSORS[message_type]
      raise ArgumentError, "Invalid event message type '#{message_type}' received." if processor.nil?

      processor.to_h object
    end

  end
end; end; end