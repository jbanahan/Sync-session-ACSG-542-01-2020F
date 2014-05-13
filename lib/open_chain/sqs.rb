class OpenChain::SQS
  #translate given object to json and add to queue
  def self.send_json queue, obj
    AWS::SQS.new(AWS_CREDENTIALS).queues[queue].send_message(obj.to_json)
  end

  #retrieve all available messages yielding each to the given block after parsing JSON to hash
  def self.retrieve_messages_as_hash queue, opts = {}
    opts = {:wait_time_seconds => 3, :idle_timeout=>3}.merge opts

    # The poll method continuously yields messages while the queue still has them, waiting at most 
    # :wait_time_seconds for new ones to appear before quitting.  It also handles deleting
    # any messages yielded to the block as long as the block completes without raising an error.

    # If the block raises, the message is left on the queue.  If used in combination with the
    # :visibility_timeout option, messages that error can be left on the queue but not visible
    # (thus not seen by subsequent poll requests for visibility_timeout seconds).  This would allow
    # for erroring messages to not block the head of the queue when utilized.
    AWS::SQS.new(AWS_CREDENTIALS).queues[queue].poll(opts) do |msg|
      obj = JSON.parse msg.body
      yield obj
    end
  end
end
