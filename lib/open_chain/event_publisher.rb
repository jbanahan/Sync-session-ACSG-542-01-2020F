module OpenChain; class EventPublisher
  QUEUES = {'test'=>'http://bad/url',
    'development'=>'https://sqs.us-east-1.amazonaws.com/468302385899/event-master-dev',
    'production'=>'https://sqs.us-east-1.amazonaws.com/468302385899/event-master-prod'}

    CONFIG ||= YAML::load_file('config/s3.yml')

    def self.publish message_type, obj, body_hash
      meta = {event_type:message_type,
        host:MasterSetup.get.request_host,
        klass:obj.class,
        id:obj.id}
      h = {:metadata=>meta,:content=>body_hash}
      AWS::SQS.new(CONFIG).client.send_message(queue_url:QUEUES[Rails.env],message_body:h.to_json)
    end
end; end