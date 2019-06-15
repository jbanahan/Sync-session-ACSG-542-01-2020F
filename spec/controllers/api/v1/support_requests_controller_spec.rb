describe Api::V1::SupportRequestsController do

  let (:user) { Factory(:user) }

  before :each do
    # Intialize the user, this also sets up the api environment
    allow_api_access user
  end

  after :each do
    SupportRequest::TestingSender.sent_requests.try(:clear)
  end

  describe "create" do
    it "creates a support request" do
      sc_config = {"more_help_message"=>"mhm"}
      allow(SupportRequest).to receive(:support_request_config).and_return sc_config
      @request.env['HTTP_REFERER'] = "http://www.vfitrack.net"

      post :create, support_request: {body: "Help!", importance: "Critical"}

      expect(response).to be_success
      sr = SupportRequest::TestingSender.sent_requests.first
      expect(sr).not_to be_nil

      # Make sure it got saved too
      sr = SupportRequest.find sr.id
      expect(sr.body).to eq "Help!"
      expect(sr.severity).to eq "Critical"
      expect(sr.referrer_url).to eq "http://www.vfitrack.net"
      expect(sr.user).to eq user

      req = JSON.parse(response.body)
      expect(JSON.parse(response.body)).to eq({"support_request_response" => {"ticket_number" => sr.ticket_number,"more_help_message"=>"mhm"}})
    end

    it "rolls back save if error occurs in sending" do
      expect_any_instance_of(SupportRequest::TestingSender).to receive(:send_request).and_raise "Error!"
      post :create, support_request: {body: "Help!", importance: "Critical"}
      expect(JSON.parse(response.body)).to eq("errors"=>["Error!"])

      expect(response).not_to be_success

      # Make sure no request was saved
      expect(SupportRequest.first).to be_nil
    end

    it "returns errors if save fails" do
      expect_any_instance_of(SupportRequest).to receive(:save).and_return false

      post :create, support_request: {body: "Help!", importance: "Critical"}
      expect(response).not_to be_success
      # Errors will technically be nil since we don't have any real AR validations, but by
      # forcing save to return blank we force the invalid path.
      expect(JSON.parse(response.body)).to eq({"errors" => []})
    end
  end
end
