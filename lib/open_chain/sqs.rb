require 'aws-sdk'
require 'open_chain/aws_config_support'

module OpenChain; class SQS
  extend OpenChain::AwsConfigSupport

  #translate given object to json and add to queue
  def self.send_json queue, json, opts = {}
    opts = {retry_count: 3, sleep: 1}.merge opts
    json_string = json.is_a?(String) ? json : json.to_json

    attempts = 0
    begin
      sqs_client.send_message queue_url: queue, message_body: json_string
    rescue => e
      if (attempts+=1) <= opts[:retry_count]
        sleep opts[:sleep]
        retry 
      end

      raise e
    end

    nil
  end

  #retrieve all available messages yielding each to the given block after parsing JSON to hash
  # If :max_message_count option is given, only that number of messages are yieled to the given block
  def self.poll queue_url, opts = {}
    # idle_timeout is the amount of time to wait for a new sqs message before stopping the polling process.
    # wait_time_seconds enables long polling and is the amount of time a single long poll will wait for a message.
    # They differ in that idle_timeout would be the max seconds to wait in a single poll call before stopping
    # the polling process.  wait_time_seconds is just the duration of the long poll.
    # max_number_of_messages grabs the given amount of messages available from the queue (1-10 are allowed values)

    # By default, we've configured poll to simply grab everything from the queue that is present and not
    # wait for any messages to show up.

    # Set wait_time_seconds and idle_timeout appropriately if you really want poll to block and wait for messages
    opts = {wait_time_seconds: 0, idle_timeout: 0, max_number_of_messages: 10, client: sqs_client}.merge opts

    max_message_count = opts.delete(:max_message_count).to_i

    poller = queue_poller(queue_url, opts)

    if max_message_count.to_i > 0
      poller.before_request do |stats|
        throw :stop_polling if stats.received_message_count >= max_message_count
      end
    end

    # The poll method continuously yields messages while the queue still has them, waiting at most 
    # :wait_time_seconds for new ones to appear before quitting.  It also handles deleting
    # any messages yielded to the block as long as the block completes without raising an error.

    # If the block raises, the message is left on the queue.  If used in combination with the
    # :visibility_timeout option, messages that error can be left on the queue but not visible
    # (thus not seen by subsequent poll requests for visibility_timeout seconds).  This would allow
    # for erroring messages to not block the head of the queue when utilized.

    # If you need to, you can also throw :stop_polling from your block if you want to stop polling as well.
    # You can throw :skip_delete as a means of telling the polling process not to delete the message
    poller.poll do |sqs_message|
      messages = []
      if opts[:max_number_of_messages].to_i > 1
        messages = sqs_message
      else
        messages << sqs_message
      end

      messages.each do |msg|
        obj = JSON.parse msg.body
        yield obj
      end
    end

    nil
  end

  def self.queue_poller queue_url, poller_opts
    Aws::SQS::QueuePoller.new(queue_url, poller_opts)
  end
  private_class_method :queue_poller

  # Retrieves an array of Aws::SQS::Types::Message objects.
  # Normally, I'd abstract away the handling of these, but since receive_message has
  # so many options that affect the data returned inside these objects, I'm letting them
  # leak out of the SQS wrapper we've written.
  # 
  # Where possible, I STRONGLY suggest using the #poll method instead of this one.
  def self.retrieve_messages queue_url, opts = {}
    opts = {queue_url: queue_url}.merge opts
    sqs_client.receive_message(opts)
  end

  # Deletes a message that you have already received.
  # message should be an Aws::SQS::Types::Message object
  def self.delete_message queue_url, message
    sqs_client.delete_message({queue_url: queue_url, receipt_handle: message.receipt_handle})
    true
  end

  # Creates the queue if it doesn't exist, and returns the queue_url
  # If queue already exists, this is a no-op on the AWS service end 
  # and the queue_url for the queue is returned.
  def self.create_queue queue_name
    resp = sqs_client.create_queue queue_name: queue_name
    resp.to_h[:queue_url]
  end

  def self.visible_message_count queue_url
    attributes = queue_attributes(queue_url, ["ApproximateNumberOfMessages"])
    attributes["ApproximateNumberOfMessages"].to_i
  end

  def self.queue_attributes queue_url, attribute_names_array
    resp = sqs_client.get_queue_attributes(queue_url: queue_url, attribute_names: attribute_names_array)
    resp.attributes
  end

  def self.sqs_client
    Aws::SQS::Client.new(aws_config)
  end
  private_class_method :sqs_client

end; end
