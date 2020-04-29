describe OpenChain::Api::ApiClient do
  before :all do
    WebMock.enable!
  end

  before :each do
    @c = OpenChain::Api::ApiClient.new 'test', 'user', 'token'
  end

  describe "initialize" do
    it "ensures valid endpoints are used" do
      expect(OpenChain::Api::ApiClient.new 'polo', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'vfitrack', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'ann', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'underarmour', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'jcrew', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'bdemo', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'das', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'll', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'dev', 'test', 'test').to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'test', 'test', 'test').to_not be_nil

      expect {OpenChain::Api::ApiClient.new 'Invalid', 'test', 'test'}.to raise_error ArgumentError, "Invalid is not a valid API endpoint."
    end

    it "uses config file to load default user / authtoken information if not given in constructor" do
      expect(OpenChain::Api::ApiClient).to receive(:get_config).and_return('test'=> {"user" => "token"})

      c = OpenChain::Api::ApiClient.new 'test'
      expect(c.username).to eq "user"
      expect(c.authtoken).to eq "token"
    end

    it "subsitutes dev endpoint on development systems" do
      expect(MasterSetup).to receive(:development_env?).and_return true
      c = OpenChain::Api::ApiClient.new 'test', 'test', 'test'
      expect(c.endpoint).to eq "http://0.0.0.0:3000"
    end

    it "does not substitute endpoint if custom feature is enabled" do
      expect(MasterSetup).to receive(:development_env?).and_return true
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Allow Production API Client in Dev").and_return true
      c = OpenChain::Api::ApiClient.new 'test', 'test', 'test'
      expect(c.endpoint).to eq "http://www.notadomain.com"
    end
  end

  describe "send_request" do
    it "sends request to given path, including standard request headers, and parses json response" do
      # This test validates the correct domain, request headers, and request format is used
      # and then that the correct response is being handled.
      stub_request(:get, 'http://www.notadomain.com/api/v1/path/file.json').
        with(
          :query => hash_including({"mf_uids" => "1,2,3"}),
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Token token="user:token"',
            'Host' => 'www.notadomain.com'
          }
        ).
        to_return(
          :body => '{"ok": "Ök"}',
          :status => 200,
          :headers => {
            'Content-Type' => "application/json; charset=utf-8"
          }
        )
        json = @c.get "/path/file.json", {"mf_uids" => "1,2,3"}
        expect(json['ok']).to eq("Ök")
        expect(WebMock).to have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").once
    end

    it "raises an error for errored responses after retrying 3 times" do
      stub_request(:get, 'http://www.notadomain.com/api/v1/path/file.json').
        with(
          :query => hash_including({"mf_uids" => "1,2,3"}),
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Token token="user:token"',
            'Host' => 'www.notadomain.com'
          }
        ).
        to_return(
          :body => '{"errors": ["Error Response"]}',
          :status => 500,
          :headers => {
            'Content-Type' => "application/json; charset=utf-8"
          }
        )
        expect {@c.get "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiError, "Error Response"
        expect(WebMock).to have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").times(3)
    end

    it "raises an error immediately on 400 errors" do
      stub_request(:get, 'http://www.notadomain.com/api/v1/path/file.json').
        with(
          :query => hash_including({"mf_uids" => "1,2,3"}),
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Token token="user:token"',
            'Host' => 'www.notadomain.com'
          }
        ).
        to_return(
          :body => '{"errors": ["Error Response"]}',
          :status => 400,
          :headers => {
            'Content-Type' => "application/json; charset=utf-8"
          }
        )
        expect {@c.get "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiError, "Error Response"
        expect(WebMock).to have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").once
    end

    it "handles 401 Authorization errors directly" do
      stub_request(:get, 'http://www.notadomain.com/api/v1/path/file.json').
        with(
          :query => hash_including({"mf_uids" => "1,2,3"}),
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Token token="user:token"',
            'Host' => 'www.notadomain.com'
          }
        ).
        to_return(
          :body => '{"errors": ["Error Response"]}',
          :status => 401,
          :headers => {
            'Content-Type' => "application/json; charset=utf-8"
          }
        )
        expect {@c.get "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiAuthenticationError, "Authentication to #{@c.endpoint} failed for user '#{@c.username}' and api token '#{@c.authtoken}'. Error: Error Response"
        expect(WebMock).to have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").once
    end

    it "handles different response charsets" do
      # The json parser ends up parsing everything to UTF-8, so we can make sure the sent charset is
      # attempted to be used by telling the parser it's ASCII when it's really UTF-8 and it should cause problems.
      stub_request(:get, 'http://www.notadomain.com/api/v1/path/file.json').
        with(
          :query => hash_including({"mf_uids" => "1,2,3"}),
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Token token="user:token"',
            'Host' => 'www.notadomain.com'
          }
        ).
        to_return(
          :body => '{"ok": "ðk"}',
          :status => 200,
          :headers => {
            'Content-Type' => "application/json; charset=us-ascii"
          }
        )

        expect {@c.get "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiError, "API Request failed with error: invalid byte sequence in US-ASCII"
        expect(WebMock).to have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3")
    end

    it "handles URL encoding parameters" do
      stub_request(:get, 'http://www.notadomain.com/api/v1/path/file.json').
        with(
          :query => "mf%2Buids=1%203",
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Token token="user:token"',
            'Host' => 'www.notadomain.com'
          }
        ).
        to_return(
          :body => '{"ok": "ok"}',
          :status => 200,
          :headers => {
            'Content-Type' => "application/json;"
          }
        )

        json = @c.get "/path/file.json", {"mf uids" => "1 3"}
        expect(json['ok']).to eq("ok")
    end
  end

  describe "not_found_error?" do
    subject { described_class }

    let (:error_404) {
      OpenChain::Api::ApiClient::ApiError.new 404, {}
    }

    it "identifies a 404 error from the API" do
      expect(subject.not_found_error? error_404).to eq true
    end

    it "identifies other errors as not not found errors" do
      expect(subject.not_found_error? StandardError.new('message')).to eq false
    end
  end
end
