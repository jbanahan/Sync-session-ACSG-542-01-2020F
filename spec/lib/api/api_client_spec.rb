# encoding: utf-8

require 'spec_helper'

describe OpenChain::Api::ApiClient do
  before :all do
    WebMock.enable!
  end
  
  before :each do
    @c = OpenChain::Api::ApiClient.new 'test', 'user', 'token'
  end
  
  describe "initialize" do
    it "ensures valid endpoints are used" do
      expect(OpenChain::Api::ApiClient.new 'polo', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'vfitrack', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'ann', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'underarmour', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'jcrew', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'bdemo', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'das', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'warnaco', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'dev', nil, nil).to_not be_nil
      expect(OpenChain::Api::ApiClient.new 'test', nil, nil).to_not be_nil

      expect{OpenChain::Api::ApiClient.new 'Invalid', nil, nil}.to raise_error ArgumentError, "Invalid is not a valid API endpoint."
    end
  end

  describe "mf_uid_list_to_param" do 
    it "converts an array of model field uid symbols to a request parameter hash" do
      param = @c.mf_uid_list_to_param [:a, :b, :c, :d]
      expect(param['mf_uids']).to eq "a,b,c,d"
    end

    it "handles nil uid lists" do
      expect(@c.mf_uid_list_to_param(nil)).to eq({})
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
        json = @c.send_request "/path/file.json", {"mf_uids" => "1,2,3"}
        json['ok'].should == "Ök"
        WebMock.should have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").once
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
        expect{@c.send_request "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiError, "Error Response"
        WebMock.should have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").times(3)
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
        expect{@c.send_request "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiError, "Error Response"
        WebMock.should have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").once
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
        expect{@c.send_request "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiAuthenticationError, "Authentication to http://www.notadomain.com failed for user user and token: Error Response"
        WebMock.should have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").once
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

        expect{@c.send_request "/path/file.json", {"mf_uids" => "1,2,3"}}.to raise_error OpenChain::Api::ApiClient::ApiError, "API Request failed with error: invalid byte sequence in US-ASCII"
        WebMock.should have_requested(:get, "http://www.notadomain.com/api/v1/path/file.json?mf_uids=1,2,3").times(3)
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

        json = @c.send_request "/path/file.json", {"mf uids" => "1 3"}
        json['ok'].should == "ok"
    end
  end
end