describe OpenChain::SqlProxyClient do

  class FakeSqlProxyClient < OpenChain::SqlProxyClient
    def self.proxy_config_key
      raise "Mock Me"
    end
  end

  let (:json_client) { OpenChain::JsonHttpClient.new }
  let (:secrets) { {"fake_config" => {'auth_token' => "config_auth_token", "url" => "config_url"}} }
  subject { FakeSqlProxyClient.new(json_client) }

  describe "request" do
    before :each do
      allow(FakeSqlProxyClient).to receive(:proxy_config_key).and_return "fake_config"
      allow(MasterSetup).to receive(:secrets).and_return secrets
    end

    it "uses json_client to request data" do
      params = {"p1" => "v"}
      request_context = {"c" => "v"}
      expect(json_client).to receive(:authorization_token=).with("config_auth_token")
      expect(json_client).to receive(:post).with("config_url/job/job_name", {'job_params' => params, "context" => request_context}).and_return "OK"
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
      expect { subject.request "job_name", {}, {}, swallow_error: false }.to raise_error "Error"
    end
  end

  describe "proxy_config" do
    it "raises an error if no config file found" do
      allow(FakeSqlProxyClient).to receive(:proxy_config_key).and_return "fake"
      expect { FakeSqlProxyClient.proxy_config }.to raise_error "No SQL Proxy client configuration file found in secrets.yml with key 'fake'."
    end

    it "memoizes proxy load" do
      allow(FakeSqlProxyClient).to receive(:proxy_config_key).and_return "fake_config"
      allow(MasterSetup).to receive(:secrets).and_return secrets

      expect(FakeSqlProxyClient.proxy_config).to eq secrets["fake_config"]
      # If the proxy wasn't memoized, then the expectations above will fail since they only
      # expect a single call to the load_file, etc
      expect(FakeSqlProxyClient.proxy_config).to eq secrets["fake_config"]
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
