require 'spec_helper'

describe OpenChain::KewillImagingSqlProxyClient do

  let! (:proxy_config) {
    config = {'test' => {'auth_token' => "config_auth_token", "url" => "config_url"}}
    allow(described_class).to receive(:proxy_config).and_return(config)
    config
  }
  let (:http_client) { instance_double(OpenChain::JsonHttpClient) }
  subject { described_class.new http_client }

  describe "request_images_added_between" do
    it "sends request" do
      start_time = Time.zone.parse "2016-11-23 00:00"
      end_time = Time.zone.parse "2016-11-23 01:00"
      request_body = {"job_params" => {start_date: start_time.in_time_zone("UTC").iso8601, end_date: end_time.in_time_zone("UTC").iso8601, customer_numbers: ["TEST", "TESTING"]}, "context" => {s3_bucket: "bucket", sqs_queue: "queue"}}
      expect(http_client).to receive(:post).with("#{proxy_config['test']['url']}/job/kewill_updated_documents", request_body, {}, proxy_config['test']['auth_token'])
      subject.request_images_added_between start_time, end_time, ["TEST", "TESTING"], "bucket", "queue"
    end

    it "handles customer numbers as string" do
      start_time = Time.zone.parse "2016-11-23 00:00"
      end_time = Time.zone.parse "2016-11-23 01:00"
      request_body = {"job_params" => {start_date: start_time.in_time_zone("UTC").iso8601, end_date: end_time.in_time_zone("UTC").iso8601, customer_numbers: ["TEST"]}, "context" => {s3_bucket: "bucket", sqs_queue: "queue"}}
      expect(http_client).to receive(:post).with("#{proxy_config['test']['url']}/job/kewill_updated_documents", request_body, {}, proxy_config['test']['auth_token'])
      subject.request_images_added_between start_time, end_time, "TEST", "bucket", "queue"
    end

    it "handles nil customer numbers" do
      start_time = Time.zone.parse "2016-11-23 00:00"
      end_time = Time.zone.parse "2016-11-23 01:00"
      request_body = {"job_params" => {start_date: start_time.in_time_zone("UTC").iso8601, end_date: end_time.in_time_zone("UTC").iso8601}, "context" => {s3_bucket: "bucket", sqs_queue: "queue"}}
      expect(http_client).to receive(:post).with("#{proxy_config['test']['url']}/job/kewill_updated_documents", request_body, {}, proxy_config['test']['auth_token'])
      subject.request_images_added_between start_time, end_time, nil, "bucket", "queue"
    end
  end
end