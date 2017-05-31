require 'spec_helper'

describe OpenChain::SqlProxyClient do
  let (:json_client) { instance_double(OpenChain::JsonHttpClient) }
  let (:config) { {'test' => {'auth_token' => "config_auth_token", "url" => "config_url"}} }
  subject { OpenChain::SqlProxyClient.new(json_client) }

  after :each do
    # Needed otherwise the config is memoized and never loaded again during the tests
    described_class.remove_instance_variable(:@proxy_config) if described_class.instance_variable_get(:@proxy_config)
  end

  describe "request" do
    before :each do
      allow(described_class).to receive(:proxy_config_file).and_return "fake/path/config.yml"
      expect(YAML).to receive(:load_file).with("fake/path/config.yml").and_return config
    end

    it "uses json_client to request data" do
      params = {"p1" => "v"}
      request_context = {"c" => "v"}
      expect(json_client).to receive(:post).with("config_url/job/job_name", {'job_params' => params, "context" => request_context}, {}, "config_auth_token").and_return "OK"
      expect(subject.request "job_name", params, request_context).to eq "OK"
    end

    it "swallows / logs and error raised by the json client" do
      params = {"p1" => "v"}
      request_context = {"c" => "v"}

      e = StandardError.new "Error"
      expect(json_client).to receive(:post).and_raise e

      expect(subject.request "job_name", params, request_context).to be_nil
      expect(ErrorLogEntry.last.additional_messages).to eq ["Failed to initiate sql_proxy query for job_name with params #{{'job_params' => params, "context" => request_context}.to_json}."]
    end

    it "raises error if specified" do
      expect(json_client).to receive(:post).and_raise "Error"
      expect{ subject.request "job_name", {}, {}, swallow_error: false }.to raise_error "Error"
    end
  end

  describe "proxy_config" do
    it "raises an error if no config file found" do
      allow(described_class).to receive(:proxy_config_file).and_return "fake/path/config.yml"
      expect { described_class.proxy_config }.to raise_error "No SQL Proxy client configuration file found at 'fake/path/config.yml'."
    end

    it "memoizes proxy load" do
      allow(described_class).to receive(:proxy_config_file).and_return "fake/path/config.yml"
      expect(YAML).to receive(:load_file).with("fake/path/config.yml").and_return config

      expect(described_class.proxy_config).to eq config
      # If the proxy wasn't memoized, then the expectations above will fail since they only
      # expect a single call to the load_file, etc
      expect(described_class.proxy_config).to eq config
    end
  end

  describe "report_query" do
    it "requests running a query" do
      params = {"1"=>"2"}
      context = {"id"=>"1"}

      body = {'job_params' => params, "context" => context}
      expect(subject).to receive(:request).with("query_name", params, context, swallow_error: false)

      subject.report_query "query_name", params, context
    end
  end

end
