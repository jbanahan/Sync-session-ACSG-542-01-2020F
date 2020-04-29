describe OpenChain::FreshserviceClient do
  let(:fs_token) { "token" }
  let(:fs_client) { described_class.new(token: fs_token) }
  let (:rest_response) {
    response = instance_double(RestClient::Response)
    allow(response).to receive(:body).and_return freshservice_json
    response
  }

  describe "initialize" do
    let (:secrets) {
      {
        "fresh_service" => {
          "api_key" => "abc"
        }
      }
    }

    it "retrieves token from default location" do
      expect(MasterSetup).to receive(:secrets).and_return secrets
      expect(described_class.new.token).to eq 'abc'
    end
  end

  describe "create_change!" do
    let(:planned_start_date) { ActiveSupport::TimeZone["UTC"].local(2016, 1, 15) }
    let(:planned_end_date) { planned_start_date + 3.minutes }

    let(:request) do
      {itil_change:{
        :subject => "VFI Track Upgrade - www - 2.0 - host_name",
        :description => "VFI Track Upgrade - www - 2.0 - host_name",
        :email => "support@vandegriftinc.com",
        :status => 1,
        :impact => 1,
        :change_type => 2,
        :group_id => 4000156520,
        :planned_start_date => "#{planned_start_date.iso8601}",
        :planned_end_date => "#{planned_end_date.iso8601}"}
      }
    end

    let (:freshservice_json) {
      {item: {itil_change: {display_id: 1}}}.to_json
    }

    it "sends data to FS" do
      expect(RestClient::Request).to receive(:execute).with({user: fs_token,
                                                             password: "password",
                                                             method: :post,
                                                             headers:{content_type: :json},
                                                             url: "https://vandegrift.freshservice.com/itil/changes.json",
                                                             payload: request.to_json})
                                                      .and_return(rest_response)

      Timecop.freeze(planned_start_date) { fs_client.create_change! "www", "2.0", "host_name" }
      expect(fs_client.change_id).to eq 1
    end

    it "raises exception if token is missing" do
      fs_client.token = nil
      expect { fs_client.create_change! "www", "2.0", "host_name" }.to raise_error "FreshserviceClient failed: No fs_token set. (Try setting up the fresh_service key in secrets.yml)"
    end

    it "raises exception if request_complete" do
      fs_client.request_complete = true
      expect { fs_client.create_change! "www", "2.0", "host_name" }.to raise_error "FreshserviceClient failed: This change request has already been sent!"
    end

    it "logs error if FS call fails" do
      e = StandardError.new "ERROR!!"
      expect(RestClient::Request).to receive(:execute).exactly(4).times.and_raise e
      allow(JSON).to receive(:parse).and_return({"item" => {"itil_change" => {}}})
      expect(fs_client).to receive(:log)
      fs_client.create_change! "www", "2.0", "host_name"
    end
  end

  describe "add_note_with_log!" do
    let(:now) { DateTime.new(2016, 1, 15)}
    let(:upgrade_log) { UpgradeLog.create!(from_version: "0", to_version: "1.0", started_at: now, finished_at: now + 3.minutes, log: "here's what happened") }
    let(:request) do
        {
          "itil_note": {
              "body":"From version: 0\nTo version: 1.0\nStarted: #{now}\nFinished: #{now + 3.minutes}\n\nhere's what happened"
           }
        }
    end

    let (:freshservice_json) {
      {"response" => "not_a_real_response"}
    }

    it "sends data to FS" do
      fs_client.change_id = 1
      expect(RestClient::Request).to receive(:execute).with({user: fs_token,
                                                             password: "password",
                                                             method: :post,
                                                             headers:{content_type: :json},
                                                             url: "https://vandegrift.freshservice.com/itil/changes/1/notes.json",
                                                             payload: request.to_json}).and_return rest_response
      fs_client.add_note_with_log! upgrade_log
      expect(fs_client.request_complete).to eq true
    end
  end

  describe "add_note!" do
    let(:now) { DateTime.new(2016, 1, 15)}
    let(:message) { "message" }
    let(:request) do
        {
          "itil_note": {
              "body":"message"
           }
        }
    end
    let (:freshservice_json) {
      {"response" => "not_a_real_response"}
    }


    it "sends data to FS" do
      fs_client.change_id = 1
      expect(RestClient::Request).to receive(:execute).with({user: fs_token,
                                                             password: "password",
                                                             method: :post,
                                                             headers:{content_type: :json},
                                                             url: "https://vandegrift.freshservice.com/itil/changes/1/notes.json",
                                                             payload: request.to_json}).and_return rest_response
      fs_client.add_note! "message"
      expect(fs_client.request_complete).to eq true
    end

    it "ignores call if request_complete" do
      fs_client.change_id = 1
      fs_client.request_complete = true
      expect(RestClient::Request).not_to receive(:execute)
      fs_client.add_note! "message"
    end

    it "raises exception if token is missing" do
      fs_client.token = nil
      expect { fs_client.add_note! "message" }.to raise_error "FreshserviceClient failed: No fs_token set. (Try setting up the fresh_service key in secrets.yml)"
      expect(fs_client.request_complete).to eq false
    end

    it "raises exception if change_id is missing" do
      fs_client.change_id = nil
      expect { fs_client.add_note! "message" }.to raise_error "FreshserviceClient failed: No change_id set."
      expect(fs_client.request_complete).to eq false
    end

    it "logs error if FS call fails" do
      fs_client.change_id = 1
      e = StandardError.new "ERROR!!"
      expect(RestClient::Request).to receive(:execute).exactly(4).times.and_raise e
      expect(fs_client).to receive(:log)
      fs_client.add_note! "message"
      expect(fs_client.request_complete).to eq false
    end
  end

  describe "log" do
    it "execute #log_me on input error" do
      e = StandardError.new "ERROR!!"
      e.set_backtrace ["backtrace 1", "backtrace 2"]
      expect_any_instance_of(StandardError).to receive(:log_me) do |instance|
        expect(instance.message).to eq "ERROR!!"
        expect(instance.backtrace).to eq ["backtrace 1", "backtrace 2"]
      end
      fs_client.log e
    end
  end
end