module OpenChain; class EventPublisher
  QUEUES = {'test'=>'http://bad/url',
    'development'=>'https://sqs.us-east-1.amazonaws.com/468302385899/event-master-dev',
    'production'=>'https://sqs.us-east-1.amazonaws.com/468302385899/event-master-prod'}

    CONFIG ||= YAML::load_file('config/s3.yml')

    MessageType = Struct.new(:type,:link_lambda,:short_message_lambda,:long_message_lambda) do
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
        api_admin = User.api_admin
        h = {event_type:type,
          host:MasterSetup.get.request_host,
          klass:obj.class.name,
          id:obj.id,
          api_token:"#{api_admin.username}:#{api_admin.api_auth_token}",
          link:self.link(obj),
          short_message:self.short_message(obj),
          long_message:self.long_message(obj)
        }
        h
      end
    end

    PROTOCOL ||= Rails.env.development? ? 'http' : 'https'

    MESSAGE_PROCESSORS ||= {
      comment_create: MessageType.new('COMMENT_CREATE',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/comments/#{obj.id}"},
        lambda {|obj| "New Comment: #{obj.subject}"},
        lambda {|obj|
          "Comment Added\n\n#{obj.body}"
        }
      ),
      order_close: MessageType.new('ORDER_CLOSE',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/orders/#{obj.id}"},
        lambda {|obj| "Order #{obj.customer_order_number} closed."},
        lambda {|obj| "Order #{obj.customer_order_number} closed by #{obj.closed_by.full_name} at #{obj.closed_at}."}
      ),
      order_reopen: MessageType.new('ORDER_REOPEN',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/orders/#{obj.id}"},
        lambda {|obj| "Order #{obj.customer_order_number} reopened."},
        lambda {|obj| "Order #{obj.customer_order_number} reopened."}
      ),
      order_accept: MessageType.new('ORDER_ACCEPT',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/orders/#{obj.id}"},
        lambda {|obj| "Order #{obj.customer_order_number} accepted."},
        lambda {|obj| "Order #{obj.customer_order_number} accepted."}
      ),
      order_unaccept: MessageType.new('ORDER_UNACCEPT',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/orders/#{obj.id}"},
        lambda {|obj| "Order #{obj.customer_order_number} unaccepted."},
        lambda {|obj| "Order #{obj.customer_order_number} unaccepted."}
      ),
      order_create: MessageType.new('ORDER_CREATE',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/orders/#{obj.id}"},
        lambda {|obj| "Order #{obj.customer_order_number} created."},
        lambda {|obj| "Order #{obj.customer_order_number} created."}
      ),
      order_update: MessageType.new('ORDER_UPDATE',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/orders/#{obj.id}"},
        lambda {|obj| "Order #{obj.customer_order_number} updated."},
        lambda {|obj| "Order #{obj.customer_order_number} updated."}
      ),
      shipment_booking_request: MessageType.new('SHIPMENT_BOOK_REQ',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/shipments/#{obj.id}"},
        lambda {|obj| "Shipment #{obj.reference} booking requested."},
        lambda {|obj| "Shipment #{obj.reference} booking requested."}
      ),
      shipment_booking_confirm: MessageType.new('SHIPMENT_BOOK_CONFIRM',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/shipments/#{obj.id}"},
        lambda {|obj| "Shipment #{obj.reference} booking confirmed."},
        lambda {|obj| "Shipment #{obj.reference} booking confirmed."}
      ),
      shipment_booking_approve: MessageType.new('SHIPMENT_BOOK_APPROVE',
        lambda {|obj| "#{PROTOCOL}://#{MasterSetup.get.request_host}/shipments/#{obj.id}"},
        lambda {|obj| "Shipment #{obj.reference} booking approved."},
        lambda {|obj| "Shipment #{obj.reference} booking approved."}
      )
    }

    def self.publish message_type, obj
      mp = MESSAGE_PROCESSORS[message_type]
      h = mp.to_h(obj)
      # Delaying to both ensure delivery, since delayed jobs will retry in the event sqs queue is not reachable,
      # and ensure all messages are only published if the outer transaction
      # actually completes (.ie not rolled back due to some greater error). If we didn't do this and the
      # object persist that's generally called prior to this method rolled back
      # then the message that was published would not accurately describe the state of the object.
      self.delay.send_queue_message(QUEUES[Rails.env], h.to_json)
    end

    def self.send_queue_message url, body
      AWS::SQS.new(CONFIG).client.send_message(queue_url:url,message_body:body)
    end
end; end
