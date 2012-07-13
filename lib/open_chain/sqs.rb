class OpenChain::SQS
  #translate given object to json and add to queue
  def self.send_json queue, obj
    AWS::SQS.new(AWS_CREDENTIALS).queues[queue].send_message(obj.to_json)
  end

  #retrieve all available messages yielding each to the given block after parsing JSON to hash
  def self.retrieve_messages_as_hash queue
    msg = nil
    begin
      msg = AWS::SQS.new(AWS_CREDENTIALS).queues[queue].receive_message
      if msg
        obj = JSON.parse msg.body
        yield obj
        msg.delete
      end
    end until msg.nil?
  end
end
