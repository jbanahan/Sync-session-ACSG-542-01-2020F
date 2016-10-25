require 'spec_helper'

describe OpenChain::SQS do

  subject { described_class }

  let! (:sqs_client) {
    sqs = instance_double("Aws::SQS::Client")
    allow(described_class).to receive(:sqs_client).and_return sqs
    sqs
  }


  describe "send_json" do
    it "sends an object to a sqs queue" do
      obj = {"abc" => 123}
      expect(sqs_client).to receive(:send_message).with(queue_url: "url", message_body: obj.to_json)

      expect(subject.send_json("url", obj)).to be_nil
    end

    it "doesn't jsonize strings" do
      sqs = instance_double("Aws::SQS::Client")
      expect(sqs_client).to receive(:send_message).with(queue_url: "url", message_body: "ABC")

      subject.send_json("url", "ABC")
    end

    it "retries failed sends 3 times" do
      expect(sqs_client).to receive(:send_message).exactly(4).times.and_raise "Error!"
      expect(subject).to receive(:sleep).with(1).exactly(3).times

      expect { subject.send_json "", "" }.to raise_error "Error!"
    end
  end

  describe "retrieve_messages" do
    it "returns retrieved messages" do
      expect(sqs_client).to receive(:receive_message).with(queue_url: "queue").and_return ["1", "2"]
      expect(subject.retrieve_messages "queue").to eq ["1", "2"]
    end
  end

  describe "delete_message" do
    it "deletes a message" do
      message = instance_double("Aws::Sqs::Types::Message")
      allow(message).to receive(:receipt_handle).and_return "message-id"
      expect(sqs_client).to receive(:delete_message).with(queue_url: "queue", receipt_handle: "message-id")
      expect(subject.delete_message("queue", message)).to be_truthy
    end
  end

  describe "create_queue" do
    it "creates a queue" do
      expect(sqs_client).to receive(:create_queue).with(queue_name: "queue").and_return({queue_url: "url"})
      expect(subject.create_queue("queue")).to eq "url"
    end
  end

  describe "visible_message_count" do
    it "retrieves number of messages in queue that can be retrieved" do
      response = double("SqsResponse")
      allow(response).to receive(:attributes).and_return({"ApproximateNumberOfMessages" => "5"})
      expect(sqs_client).to receive(:get_queue_attributes).with(queue_url: "queue", attribute_names: ["ApproximateNumberOfMessages"]).and_return response
      expect(subject.visible_message_count("queue")).to eq 5
    end      
  end

  describe "queue_attributes" do
    it "retrieves queue attributes" do
      attribute_hash = {}
      response = double("SqsResponse")
      allow(response).to receive(:attributes).and_return(attribute_hash)

      expect(sqs_client).to receive(:get_queue_attributes).with(queue_url: "queue", attribute_names: ["Att1", "Att2"]).and_return response

      expect(subject.queue_attributes("queue", ["Att1", "Att2"])).to be attribute_hash
    end
  end

  describe "poll" do
    
    it "polls queue for messages and yields them to given block" do
      poller = instance_double("Aws::SQS::QueuePoller")
      expect(subject).to receive(:queue_poller).with("queue", {wait_time_seconds: 0, idle_timeout: 0, max_number_of_messages: 10, client: sqs_client}).and_return poller

      message = instance_double("Aws:SQS::Types::Message")
      allow(message).to receive(:body).and_return '{"abc":123}'
      expect(poller).to receive(:poll).and_yield([message])

      messages = []
      subject.poll("queue") {|msg| messages << msg}
      expect(messages.length).to eq 1
      expect(messages.first).to eq({"abc" => 123})
    end

    it "polls queue for messages and yields them to given block when only a single message is requested" do
      poller = instance_double("Aws::SQS::QueuePoller")
      expect(subject).to receive(:queue_poller).with("queue", {wait_time_seconds: 0, idle_timeout: 0, max_number_of_messages: 1, client: sqs_client}).and_return poller

      message = instance_double("Aws:SQS::Types::Message")
      allow(message).to receive(:body).and_return '{"abc":123}'
      expect(poller).to receive(:poll).and_yield(message)

      messages = []
      subject.poll("queue", max_number_of_messages: 1) {|msg| messages << msg}
      expect(messages.length).to eq 1
      expect(messages.first).to eq({"abc" => 123})
    end

    it "adds a before_request callback if a max_message_count option is utilized that throws an error if message count is over max" do
      poller = instance_double("Aws::SQS::QueuePoller")
      expect(subject).to receive(:queue_poller).with("queue", {wait_time_seconds: 0, idle_timeout: 0, max_number_of_messages: 10, client: sqs_client}).and_return poller

      stats = double("QueuePoller::Stats")
      expect(stats).to receive(:received_message_count).and_return 1
      expect(poller).to receive(:before_request).and_yield stats

      expect { subject.poll("queue", {max_message_count: 1})}.to throw_symbol :stop_polling
    end

    it "adds a before_request callback if a max_message_count option is utilized that does not throw an error if message count is under max" do
      poller = instance_double("Aws::SQS::QueuePoller")
      expect(subject).to receive(:queue_poller).with("queue", {wait_time_seconds: 0, idle_timeout: 0, max_number_of_messages: 10, client: sqs_client}).and_return poller

      stats = double("QueuePoller::Stats")
      expect(stats).to receive(:received_message_count).and_return 0
      expect(poller).to receive(:before_request).and_yield stats

      expect { subject.poll("queue", {max_message_count: 1}) }.not_to throw_symbol :stop_polling
    end
  end
end