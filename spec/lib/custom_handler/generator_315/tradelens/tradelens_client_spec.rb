describe OpenChain::CustomHandler::Generator315::Tradelens::TradelensClient do

  let(:session) { Factory(:api_session, retry_count: 0, class_name: "OpenChain::CustomHandler::Generator315::Tradelens::CustomReleaseHandler") }

  let(:secrets_file) do
    {"tradelens" => {"org_id" => "org",
                     "api_key" => "api",
                     "domain" => "tradelens-domain.com",
                     "solution_id" => "gtd-solution"},
     "redis" => {"server" => "localhost",
                 "port" => 6379}}
  end

  let(:request_hsh) do
    {"originatorName" => "Walshop", "originatorId" => "WLSH",
     "eventSubmissionTime8601" => "2018-03-10T11:30:00.000-05:00", "equipmentNumber" => "container_num",
     "billOfLadingNumber" => "mbol", "eventOccurrenceTime8601" => "2018-03-13T11:30:00.000-05:00"}
  end

  let(:response_hsh) do
    {"message" => "Event submitted", "eventTransactionId" => "6e4f8bf9-e5af-4248-99a3-d613bb9f70d4"}
  end

  let(:endpoint) { "/api/v1/genericEvents/customsRelease" }
  let(:client) { described_class.new endpoint }

  before { allow(MasterSetup).to receive(:secrets).and_return secrets_file }

  describe "send_milestone" do
    it "sends to sandbox" do
      expect(client).to receive(:onboarding_token).with(use_cache: true).and_return "onb-token"
      expect(client.http_client).to receive(:post).with("https://tradelens-domain.com#{endpoint}",
                                                        request_hsh.to_json,
                                                        {"Content-Type" => "application/json",
                                                         "Accept" => "application/json",
                                                         "Authorization" => "Bearer onb-token"})
                                                  .and_return(response_hsh)
      expect(client).to receive(:log_response).with(response_hsh, "OK", session.id)
      client.send_milestone request_hsh, session.id, delay: false
    end

    it "does nothing if there's no mode" do
      allow(MasterSetup).to receive(:secrets).and_return({})
      expect(client.http_client).not_to receive(:post)
      client.send_milestone request_hsh, session.id, delay: false
    end

    it "delays when specified" do
      delayed_client = class_double(described_class)
      expect(described_class).to receive(:delay).and_return delayed_client
      expect(delayed_client).to receive(:send_milestone).with(request_hsh, endpoint, session.id)

      client.send_milestone request_hsh, session.id, delay: true
    end

    context "error handling" do
      before do
        allow(client).to receive(:onboarding_token).and_return "onb-token"
      end

      it "raises/logs 401 only after 10th try" do

        counter = 0
        err = OpenChain::HttpErrorWithResponse.new
        err.http_status = "401"
        err.http_response_body = {"error" => "BAD!"}

        allow(client.http_client).to receive(:post) do
          counter += 1
          raise err
        end

        expect(client).to receive(:log_response).with({"error" => "BAD!"}, "401", session.id)
        expect { client.send_milestone(request_hsh, session.id, delay: false) }.to raise_error err
        expect(counter).to eq 10
      end

      it "raises/logs other errors after first try" do
        counter = 0
        err = OpenChain::HttpErrorWithResponse.new
        err.http_status = "400"
        err.http_response_body = {"error" => "BAD!"}

        allow(client.http_client).to receive(:post) do
          counter += 1
          raise err
        end

        expect(client).to receive(:log_response).with({"error" => "BAD!"}, "400", session.id)
        expect { client.send_milestone(request_hsh, session.id, delay: false) }.to raise_error err
        expect(counter).to eq 1
      end
    end
  end

  describe "access_token" do

    it "returns value from cache when specified" do

      expect_any_instance_of(TestExtensions::MockCache).to receive(:get).with('tradelens_access_token').and_return "access"
      expect(client).not_to receive(:generate_access_token)

      expect(client.access_token(use_cache: true)).to eq "access"
    end

    it "sets cache when empty" do
      expect_any_instance_of(TestExtensions::MockCache).to receive(:get).with('tradelens_access_token').and_return nil
      expect(client.http_client).to receive(:post).with("https://iam.cloud.ibm.com/identity/token",
                                                        "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=api",
                                                        "Content-Type" => "application/x-www-form-urlencoded")
                                                  .and_return "access"

      expect(client.access_token(use_cache: true)).to eq "access"
    end

    it "sets cache when directed" do
      expect_any_instance_of(TestExtensions::MockCache).not_to receive(:get)
      expect(client.http_client).to receive(:post).with("https://iam.cloud.ibm.com/identity/token",
                                                        "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=api",
                                                        "Content-Type" => "application/x-www-form-urlencoded")
                                                  .and_return "access"

      expect(client.access_token(use_cache: false)).to eq "access"
    end

  end

  describe "onboarding_token" do
    it "returns value from cache when specified" do

      expect(client).to receive(:access_token).with(use_cache: true).and_return("access")
      expect_any_instance_of(TestExtensions::MockCache).to receive(:get).with('tradelens_onboarding_token').and_return "onboarding"
      expect(client).not_to receive(:generate_access_token)

      expect(client.onboarding_token(use_cache: true)).to eq "onboarding"
    end

    it "sets cache when empty" do
      expect(client).to receive(:access_token).with(use_cache: true).and_return("access")
      expect_any_instance_of(TestExtensions::MockCache).to receive(:get).with('tradelens_onboarding_token').and_return nil
      expect(client.http_client).to receive(:post).with("https://tradelens-domain.com/onboarding/v1/iam/exchange_token/solution/gtd-solution/organization/org",
                                                        "access",
                                                        "Content-Type" => "application/json")
                                                  .and_return({"onboarding_token" => "onboarding"})

      expect(client.onboarding_token(use_cache: true)).to eq "onboarding"
    end

    it "sets cache when directed" do
      expect(client).to receive(:access_token).with(use_cache: false).and_return("access")
      expect_any_instance_of(TestExtensions::MockCache).not_to receive(:get)
      expect(client.http_client).to receive(:post).with("https://tradelens-domain.com/onboarding/v1/iam/exchange_token/solution/gtd-solution/organization/org",
                                                        "access",
                                                        "Content-Type" => "application/json")
                                                  .and_return({"onboarding_token" => "onboarding"})

      expect(client.onboarding_token(use_cache: false)).to eq "onboarding"
    end
  end

  describe "log_response" do
    it "updates session, adds response attachment" do
      t = Tempfile.new
      expect(Tempfile).to receive(:open).with(["CustomReleaseHandler_response_1_", ".json"]).and_yield t

      client.log_response response_hsh, "OK", session.id
      session.reload
      expect(session.retry_count).to eq 0
      expect(session.last_server_response).to eq "OK"
      expect(session.class_name).to eq "OpenChain::CustomHandler::Generator315::Tradelens::CustomReleaseHandler"

      expect(session.attachments.count).to eq 1
      att = session.attachments.first
      expect(att.attachment_type).to eq "response"
      expect(att.uploaded_by).to eq User.integration

      t.rewind

      expect(JSON.parse(t.read)).to eq response_hsh
      t.close
    end

    it "starts updating the retry_count once there's been an update" do
      session.update! last_server_response: "400"
      client.log_response response_hsh, "OK", session.id
      session.reload
      expect(session.retry_count).to eq 1
    end
  end
end
